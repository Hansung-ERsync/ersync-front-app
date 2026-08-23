import '../../../../core/error/app_exception.dart';
import '../../domain/entities/assessment_enums.dart';
import '../../domain/entities/patient_assessment_draft.dart';
import '../../domain/entities/transfer_request_receipt.dart';

class MockPatientAssessmentDataSource {
  MockPatientAssessmentDataSource({
    required this.callbackContact,
    this.assessmentProtocolVersion = 'ERSYNC_MVP_1.0',
    this.preKtasStandardVersion = 'DEV_UNCONFIRMED',
  });

  final String callbackContact;
  final String assessmentProtocolVersion;
  final String preKtasStandardVersion;
  PatientAssessmentDraft? _savedDraft;
  final List<PatientAssessmentDraft> _submittedRequests =
      <PatientAssessmentDraft>[];

  Future<PatientAssessmentDraft> loadDraft() async {
    await _delay();
    return _savedDraft ?? _sampleDraft();
  }

  Future<void> saveDraft(PatientAssessmentDraft draft) async {
    await _delay();
    _savedDraft = draft;
  }

  Future<void> clearDraft() async {
    await _delay();
    _savedDraft = null;
  }

  Future<TransferRequestReceipt> submit(PatientAssessmentDraft draft) async {
    await _delay(const Duration(milliseconds: 350));

    if (draft.callbackContact.isEmpty) {
      throw const AppException('등록된 회신 연락처를 확인해주세요.');
    }

    final int existingIndex = _submittedRequests.indexWhere(
      (PatientAssessmentDraft item) =>
          item.clientRequestKey == draft.clientRequestKey,
    );
    if (existingIndex < 0) {
      _submittedRequests.add(draft);
    }

    final int requestNumber = existingIndex < 0
        ? _submittedRequests.length
        : existingIndex + 1;
    return TransferRequestReceipt(
      requestId: 'REQ-MOCK-${requestNumber.toString().padLeft(4, '0')}',
      createdAt: DateTime.now(),
      currentSearchRadiusKm: 10,
      radiusStepKm: 10,
      expansionIntervalSeconds: 60,
      maximumSearchRadiusKm: 100,
    );
  }

  PatientAssessmentDraft _sampleDraft() {
    final DateTime now = DateTime.now();
    return PatientAssessmentDraft(
      assessmentProtocolVersion: assessmentProtocolVersion,
      preKtasStandardVersion: preKtasStandardVersion,
      clientRequestKey: 'mock-${now.microsecondsSinceEpoch}',
      sceneAddress: '서울 강동구 천호대로 892',
      latitude: 37.5386,
      longitude: 127.1238,
      locationSource: 'GPS',
      callbackContact: callbackContact,
      ageStatus: null,
      ageYears: null,
      sex: null,
      occurrenceType: null,
      occurrenceDetail: '',
      mechanism: null,
      injurySites: const <InjurySite>{},
      primarySymptom: null,
      primarySymptomDetail: '',
      secondarySymptoms: const <PatientSymptom>{},
      onsetTimeStatus: null,
      onsetAt: null,
      classificationStatus: null,
      preKtasLevel: null,
      exceptionReason: null,
      exceptionDetail: '',
      avpu: null,
      unassessableReason: null,
      unassessableDetail: '',
      assessedAt: now,
      observedAt: now,
      vitals: const <VitalType, VitalReadingDraft>{},
      measuredAt: now,
      treatments: const <TreatmentType>{},
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

  Future<void> _delay([Duration duration = const Duration(milliseconds: 120)]) {
    return Future<void>.delayed(duration);
  }
}
