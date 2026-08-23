import 'dart:async';

import 'package:er_sync/features/patient_assessment/domain/entities/assessment_enums.dart';
import 'package:er_sync/features/patient_assessment/domain/entities/patient_assessment_draft.dart';
import 'package:er_sync/features/patient_assessment/domain/entities/transfer_request_receipt.dart';
import 'package:er_sync/features/patient_assessment/domain/repositories/patient_assessment_repository.dart';
import 'package:er_sync/features/patient_assessment/presentation/providers/patient_assessment_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('서버와 GPS 초기화를 기다리지 않고 빈 입력 화면 상태를 즉시 제공한다', () async {
    final ProviderContainer container = ProviderContainer();
    final ProviderSubscription<AsyncValue<PatientAssessmentViewState>>
    subscription = container.listen(
      patientAssessmentViewModelProvider,
      (
        AsyncValue<PatientAssessmentViewState>? previous,
        AsyncValue<PatientAssessmentViewState> next,
      ) {},
      fireImmediately: true,
    );
    addTearDown(() {
      subscription.close();
      container.dispose();
    });

    final AsyncValue<PatientAssessmentViewState> initial = container.read(
      patientAssessmentViewModelProvider,
    );
    expect(initial.hasValue, isTrue);
    expect(initial.requireValue.isPreparingRequest, isTrue);
    expect(initial.requireValue.isDraftReady, isFalse);
    expect(initial.requireValue.draft.ageStatus, isNull);

    container
        .read(patientAssessmentViewModelProvider.notifier)
        .setAgeStatus(AgeStatus.unknown);

    await _waitUntil(
      () => container
          .read(patientAssessmentViewModelProvider)
          .requireValue
          .isDraftReady,
    );
    final PatientAssessmentViewState ready = container
        .read(patientAssessmentViewModelProvider)
        .requireValue;
    expect(ready.draft.ageStatus, AgeStatus.unknown);
    expect(ready.draft.assessmentProtocolVersion, isNotEmpty);
    expect(ready.draft.sceneAddress, isNot('현재 위치 확인 중'));
  });

  test('마지막 입력을 확정 저장한 뒤 동일한 스냅샷으로 이송 요청을 보낸다', () async {
    final _RecordingPatientAssessmentRepository repository =
        _RecordingPatientAssessmentRepository(_completedDraft());
    final ProviderContainer container = ProviderContainer(
      overrides: [
        patientAssessmentRepositoryProvider.overrideWithValue(repository),
      ],
    );
    final ProviderSubscription<AsyncValue<PatientAssessmentViewState>>
    subscription = container.listen(
      patientAssessmentViewModelProvider,
      (
        AsyncValue<PatientAssessmentViewState>? previous,
        AsyncValue<PatientAssessmentViewState> next,
      ) {},
      fireImmediately: true,
    );
    addTearDown(() {
      subscription.close();
      container.dispose();
    });
    await _waitUntil(
      () => container
          .read(patientAssessmentViewModelProvider)
          .requireValue
          .isDraftReady,
    );

    final PatientAssessmentViewModel viewModel = container.read(
      patientAssessmentViewModelProvider.notifier,
    );
    viewModel.setMedications('방금 입력한 혈압약');
    final Future<TransferRequestReceipt?> submission = viewModel.submit();

    await repository.saveStarted;
    expect(repository.submittedDraft, isNull);
    expect(repository.savingDraft?.medications, '방금 입력한 혈압약');

    repository.completeSave();
    final TransferRequestReceipt? receipt = await submission;

    expect(receipt?.requestId, 'REQUEST-1');
    expect(repository.events, <String>[
      'save-started',
      'save-completed',
      'submit',
      'clear',
    ]);
    expect(
      identical(repository.savingDraft, repository.submittedDraft),
      isTrue,
    );
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (int attempt = 0; attempt < 20; attempt++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  fail('환자 평가 초기화가 제한 시간 안에 완료되지 않았습니다.');
}

PatientAssessmentDraft _completedDraft() {
  final DateTime now = DateTime(2026, 8, 17, 15);
  return PatientAssessmentDraft(
    assessmentProtocolVersion: 'ERSYNC_MVP_1.0',
    preKtasStandardVersion: 'DEV_UNCONFIRMED',
    clientRequestKey: 'transport-request-1',
    sceneAddress: '서울특별시 중구 세종대로 110',
    latitude: 37.5663,
    longitude: 126.9779,
    locationSource: 'GPS',
    callbackContact: '010-0000-0000',
    ageStatus: AgeStatus.exact,
    ageYears: 67,
    sex: PatientSex.male,
    occurrenceType: OccurrenceType.disease,
    occurrenceDetail: '',
    mechanism: null,
    injurySites: const <InjurySite>{},
    primarySymptom: PatientSymptom.chestPain,
    primarySymptomDetail: '',
    secondarySymptoms: const <PatientSymptom>{},
    onsetTimeStatus: ClinicalTimeStatus.unknown,
    onsetAt: null,
    classificationStatus: ClassificationStatus.completed,
    preKtasLevel: 2,
    exceptionReason: null,
    exceptionDetail: '',
    avpu: AvpuLevel.alert,
    unassessableReason: null,
    unassessableDetail: '',
    assessedAt: now,
    observedAt: now,
    vitals: <VitalType, VitalReadingDraft>{
      for (final VitalType type in VitalType.values)
        type: const VitalReadingDraft(state: MeasurementState.refused),
    },
    measuredAt: now,
    treatments: const <TreatmentType>{TreatmentType.none},
    treatmentEntries: const <TreatmentType, TreatmentEntryDraft>{},
    performedAt: now,
    glucoseMgDl: null,
    leftPupil: null,
    rightPupil: null,
    medicalHistory: '',
    allergies: '',
    medications: '',
    isolationConcern: null,
    enteredAt: now,
  );
}

class _RecordingPatientAssessmentRepository
    implements PatientAssessmentRepository {
  _RecordingPatientAssessmentRepository(this.initialDraft);

  final PatientAssessmentDraft initialDraft;
  final Completer<void> _saveStarted = Completer<void>();
  final Completer<void> _saveCompletion = Completer<void>();
  final List<String> events = <String>[];
  PatientAssessmentDraft? savingDraft;
  PatientAssessmentDraft? submittedDraft;

  Future<void> get saveStarted => _saveStarted.future;

  void completeSave() => _saveCompletion.complete();

  @override
  Future<PatientAssessmentDraft> loadDraft() async => initialDraft;

  @override
  Future<void> saveDraft(PatientAssessmentDraft draft) async {
    savingDraft = draft;
    events.add('save-started');
    _saveStarted.complete();
    await _saveCompletion.future;
    events.add('save-completed');
  }

  @override
  Future<TransferRequestReceipt> submit(PatientAssessmentDraft draft) async {
    submittedDraft = draft;
    events.add('submit');
    return TransferRequestReceipt(
      requestId: 'REQUEST-1',
      createdAt: DateTime(2026, 8, 17, 15),
      currentSearchRadiusKm: 10,
      radiusStepKm: 10,
      expansionIntervalSeconds: 60,
      maximumSearchRadiusKm: 100,
    );
  }

  @override
  Future<void> clearDraft() async {
    events.add('clear');
  }
}
