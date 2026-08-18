import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/idempotency/idempotency_providers.dart';
import '../../../../core/location/device_location.dart';
import '../../../../core/location/location_providers.dart';
import '../../../../core/network/api_providers.dart';
import '../../../auth/data/datasources/mock_auth_data_source.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_view_model.dart';
import '../../data/datasources/mock_patient_assessment_data_source.dart';
import '../../data/repositories/mock_patient_assessment_repository.dart';
import '../../data/repositories/api_patient_assessment_repository.dart';
import '../../data/storage/patient_assessment_draft_store.dart';
import '../../domain/entities/assessment_enums.dart';
import '../../domain/entities/patient_assessment_draft.dart';
import '../../domain/entities/transfer_request_receipt.dart';
import '../../domain/repositories/patient_assessment_repository.dart';
import '../../domain/usecases/clear_patient_assessment_draft.dart';
import '../../domain/usecases/load_patient_assessment_draft.dart';
import '../../domain/usecases/save_patient_assessment_draft.dart';
import '../../domain/usecases/submit_transfer_request.dart';
import '../widgets/assessment_validation.dart';

final Provider<MockPatientAssessmentDataSource>
mockPatientAssessmentDataSourceProvider =
    Provider<MockPatientAssessmentDataSource>((Ref ref) {
      final AuthUser? user = ref.watch(
        authViewModelProvider.select((AuthState state) => state.user),
      );
      return MockPatientAssessmentDataSource(
        callbackContact:
            user?.callbackContact ?? MockAuthDataSource.mockCallbackContact,
      );
    });

final Provider<PatientAssessmentRepository>
patientAssessmentRepositoryProvider = Provider<PatientAssessmentRepository>(
  (Ref ref) => MockPatientAssessmentRepository(
    ref.watch(mockPatientAssessmentDataSourceProvider),
  ),
);

final Provider<PatientAssessmentRepository>
apiPatientAssessmentRepositoryProvider = Provider<PatientAssessmentRepository>((
  Ref ref,
) {
  final AuthUser? user = ref.watch(
    authViewModelProvider.select((AuthState state) => state.user),
  );
  return ApiPatientAssessmentRepository(
    ref.watch(dioProvider),
    callbackContact:
        user?.callbackContact ?? MockAuthDataSource.mockCallbackContact,
    locationService: ref.watch(deviceLocationServiceProvider),
    draftStore: SecurePatientAssessmentDraftStore(
      accountId: user?.accountId ?? 'signed-out',
    ),
    idempotencyKeyGenerator: ref.watch(idempotencyKeyGeneratorProvider),
  );
});

final Provider<LoadPatientAssessmentDraft> loadPatientAssessmentDraftProvider =
    Provider<LoadPatientAssessmentDraft>(
      (Ref ref) => LoadPatientAssessmentDraft(
        ref.watch(patientAssessmentRepositoryProvider),
      ),
    );

final Provider<SavePatientAssessmentDraft> savePatientAssessmentDraftProvider =
    Provider<SavePatientAssessmentDraft>(
      (Ref ref) => SavePatientAssessmentDraft(
        ref.watch(patientAssessmentRepositoryProvider),
      ),
    );

final Provider<ClearPatientAssessmentDraft>
clearPatientAssessmentDraftProvider = Provider<ClearPatientAssessmentDraft>(
  (Ref ref) => ClearPatientAssessmentDraft(
    ref.watch(patientAssessmentRepositoryProvider),
  ),
);

final Provider<SubmitTransferRequest> submitTransferRequestProvider =
    Provider<SubmitTransferRequest>(
      (Ref ref) =>
          SubmitTransferRequest(ref.watch(patientAssessmentRepositoryProvider)),
    );

final AsyncNotifierProvider<
  PatientAssessmentViewModel,
  PatientAssessmentViewState
>
patientAssessmentViewModelProvider =
    AsyncNotifierProvider.autoDispose<
      PatientAssessmentViewModel,
      PatientAssessmentViewState
    >(PatientAssessmentViewModel.new);

class PatientAssessmentViewModel
    extends AsyncNotifier<PatientAssessmentViewState> {
  Timer? _draftSaveTimer;
  bool _isDisposed = false;
  bool _isDiscarding = false;
  bool _hasUserEdits = false;

  @override
  PatientAssessmentViewState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _draftSaveTimer?.cancel();
    });
    final AuthUser? user = ref.watch(
      authViewModelProvider.select((AuthState state) => state.user),
    );
    final PatientAssessmentDraft initialDraft = _createPreparingDraft(
      callbackContact:
          user?.callbackContact ?? MockAuthDataSource.mockCallbackContact,
      clientRequestKey: ref
          .watch(idempotencyKeyGeneratorProvider)
          .create('transport'),
    );
    final LoadPatientAssessmentDraft loader = ref.watch(
      loadPatientAssessmentDraftProvider,
    );
    Future<void>.microtask(() => _initializeDraft(loader));
    return PatientAssessmentViewState(
      draft: initialDraft,
      isPreparingRequest: true,
      isDraftReady: false,
    );
  }

  Future<void> retryPreparation() async {
    final PatientAssessmentViewState current = state.requireValue;
    if (current.isPreparingRequest || _isDiscarding) {
      return;
    }
    _setViewState(
      current.copyWith(
        isPreparingRequest: true,
        isDraftReady: false,
        clearPreparationError: true,
        clearError: true,
      ),
    );
    await _initializeDraft(ref.read(loadPatientAssessmentDraftProvider));
  }

  Future<void> _initializeDraft(LoadPatientAssessmentDraft loader) async {
    try {
      final PatientAssessmentDraft loaded = await loader.call();
      if (_isDisposed || _isDiscarding) {
        return;
      }
      final PatientAssessmentViewState current = state.requireValue;
      final PatientAssessmentDraft merged = _hasUserEdits
          ? current.draft.copyWith(
              assessmentProtocolVersion: loaded.assessmentProtocolVersion,
              preKtasStandardVersion: loaded.preKtasStandardVersion,
              clientRequestKey: loaded.clientRequestKey,
              sceneAddress: loaded.sceneAddress,
              latitude: loaded.latitude,
              longitude: loaded.longitude,
              locationSource: loaded.locationSource,
              callbackContact: loaded.callbackContact,
              enteredAt: loaded.enteredAt,
            )
          : loaded;
      final bool requiresCurrentLocation = loaded.sceneAddress == '최근 GPS 위치';
      _setViewState(
        current.copyWith(
          draft: merged,
          isPreparingRequest: requiresCurrentLocation,
          isDraftReady: !requiresCurrentLocation,
          clearPreparationError: true,
        ),
      );
      if (requiresCurrentLocation) {
        await _refreshCurrentLocation();
      } else if (_hasUserEdits) {
        unawaited(ref.read(savePatientAssessmentDraftProvider)(merged));
      }
    } on AppException catch (error) {
      _setPreparationError(error.message);
    } on Object {
      _setPreparationError('요청 정보를 준비하지 못했습니다. 다시 시도해주세요.');
    }
  }

  Future<void> _refreshCurrentLocation() async {
    try {
      final DeviceLocationPoint location = await ref
          .read(deviceLocationServiceProvider)
          .getCurrentLocation();
      if (_isDisposed || _isDiscarding) {
        return;
      }
      final PatientAssessmentViewState current = state.requireValue;
      final PatientAssessmentDraft updated = current.draft.copyWith(
        sceneAddress: '현재 GPS 위치',
        latitude: location.latitude,
        longitude: location.longitude,
        locationSource: 'GPS',
      );
      _setViewState(
        current.copyWith(
          draft: updated,
          isPreparingRequest: false,
          isDraftReady: true,
          clearPreparationError: true,
        ),
      );
      unawaited(ref.read(savePatientAssessmentDraftProvider)(updated));
    } on AppException catch (error) {
      _setPreparationError(error.message);
    } on Object {
      _setPreparationError('현재 GPS 위치를 확인하지 못했습니다. 다시 시도해주세요.');
    }
  }

  void _setPreparationError(String message) {
    if (_isDisposed || _isDiscarding) {
      return;
    }
    final PatientAssessmentViewState current = state.requireValue;
    _setViewState(
      current.copyWith(
        isPreparingRequest: false,
        isDraftReady: false,
        preparationErrorMessage: message,
      ),
    );
  }

  void setAgeStatus(AgeStatus value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(
        ageStatus: value,
        ageYears: value == AgeStatus.unknown ? null : draft.ageYears,
      ),
    );
  }

  void setAgeYears(int? value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(ageYears: value),
    );
  }

  void setSex(PatientSex value) {
    _updateDraft((PatientAssessmentDraft draft) => draft.copyWith(sex: value));
  }

  void setOccurrenceType(OccurrenceType value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(
        occurrenceType: value,
        occurrenceDetail: value == OccurrenceType.other
            ? draft.occurrenceDetail
            : '',
        mechanism: value == OccurrenceType.nonDisease ? draft.mechanism : null,
        injurySites: value == OccurrenceType.nonDisease
            ? draft.injurySites
            : const <InjurySite>{},
      ),
    );
  }

  void setOccurrenceDetail(String value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(occurrenceDetail: value),
    );
  }

  void setMechanism(InjuryMechanism value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(mechanism: value),
    );
  }

  void toggleInjurySite(InjurySite value) {
    _updateDraft((PatientAssessmentDraft draft) {
      final Set<InjurySite> updated = Set<InjurySite>.of(draft.injurySites);
      if (!updated.add(value)) {
        updated.remove(value);
      }
      if (value == InjurySite.unknown && updated.contains(value)) {
        return draft.copyWith(
          injurySites: const <InjurySite>{InjurySite.unknown},
        );
      }
      updated.remove(InjurySite.unknown);
      return draft.copyWith(injurySites: updated);
    });
  }

  void setOnsetTimeStatus(ClinicalTimeStatus value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(
        onsetTimeStatus: value,
        onsetAt: value == ClinicalTimeStatus.unknown
            ? null
            : draft.onsetAt ?? DateTime.now(),
      ),
    );
  }

  void setOnsetAt(DateTime value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(onsetAt: value),
    );
  }

  void setOnsetTimeSelection(ClinicalTimeStatus status, DateTime? occurredAt) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(
        onsetTimeStatus: status,
        onsetAt: status == ClinicalTimeStatus.unknown ? null : occurredAt,
      ),
    );
  }

  void setPrimarySymptom(PatientSymptom value) {
    _updateDraft((PatientAssessmentDraft draft) {
      final Set<PatientSymptom> secondary = Set<PatientSymptom>.of(
        draft.secondarySymptoms,
      )..remove(value);
      return draft.copyWith(
        primarySymptom: value,
        primarySymptomDetail: value == PatientSymptom.other
            ? draft.primarySymptomDetail
            : '',
        secondarySymptoms: secondary,
      );
    });
  }

  void setPrimarySymptomDetail(String value) {
    _updateDraft(
      (PatientAssessmentDraft draft) =>
          draft.copyWith(primarySymptomDetail: value),
    );
  }

  void toggleSecondarySymptom(PatientSymptom value) {
    _updateDraft((PatientAssessmentDraft draft) {
      if (draft.primarySymptom == value) {
        return draft;
      }
      final Set<PatientSymptom> updated = Set<PatientSymptom>.of(
        draft.secondarySymptoms,
      );
      if (!updated.add(value)) {
        updated.remove(value);
      }
      return draft.copyWith(secondarySymptoms: updated);
    });
  }

  void setClassificationStatus(ClassificationStatus value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(
        classificationStatus: value,
        preKtasLevel: value == ClassificationStatus.completed
            ? draft.preKtasLevel
            : null,
        exceptionReason: value == ClassificationStatus.emergencyUnfinished
            ? draft.exceptionReason
            : null,
        exceptionDetail: value == ClassificationStatus.emergencyUnfinished
            ? draft.exceptionDetail
            : '',
      ),
    );
  }

  void setPreKtasLevel(int value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(preKtasLevel: value),
    );
  }

  void setEmergencyReason(EmergencyExceptionReason value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(
        exceptionReason: value,
        exceptionDetail: value == EmergencyExceptionReason.other
            ? draft.exceptionDetail
            : '',
      ),
    );
  }

  void setExceptionDetail(String value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(exceptionDetail: value),
    );
  }

  void setAvpu(AvpuLevel value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(
        avpu: value,
        unassessableReason: value == AvpuLevel.unassessable
            ? draft.unassessableReason
            : null,
        unassessableDetail: value == AvpuLevel.unassessable
            ? draft.unassessableDetail
            : '',
      ),
    );
  }

  void setUnassessableReason(UnassessableReason value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(
        unassessableReason: value,
        unassessableDetail: value == UnassessableReason.other
            ? draft.unassessableDetail
            : '',
      ),
    );
  }

  void setUnassessableDetail(String value) {
    _updateDraft(
      (PatientAssessmentDraft draft) =>
          draft.copyWith(unassessableDetail: value),
    );
  }

  void setAssessmentTime(DateTime value) {
    _updateDraft(
      (PatientAssessmentDraft draft) =>
          draft.copyWith(assessedAt: value, observedAt: value),
    );
  }

  void setVitalState(VitalType type, MeasurementState value) {
    _updateVital(type, (VitalReadingDraft current) {
      if (value == MeasurementState.value) {
        return current.copyWith(
          state: value,
          value: current.value ?? _referenceVitalValue(type),
          secondaryValue: type == VitalType.bloodPressure
              ? current.secondaryValue ?? 70.0
              : null,
          unavailableReason: null,
          unavailableReasonDetail: '',
        );
      }
      return current.copyWith(
        state: value,
        value: null,
        secondaryValue: null,
        unavailableReason: value == MeasurementState.unavailable
            ? current.unavailableReason
            : null,
        unavailableReasonDetail:
            value == MeasurementState.unavailable &&
                current.unavailableReason == MeasurementUnavailableReason.other
            ? current.unavailableReasonDetail
            : '',
      );
    });
  }

  void setVitalUnavailableReason(
    VitalType type,
    MeasurementUnavailableReason value,
  ) {
    _updateVital(
      type,
      (VitalReadingDraft current) => current.copyWith(
        unavailableReason: value,
        unavailableReasonDetail: value == MeasurementUnavailableReason.other
            ? current.unavailableReasonDetail
            : '',
      ),
    );
  }

  void setVitalUnavailableReasonDetail(VitalType type, String value) {
    _updateVital(
      type,
      (VitalReadingDraft current) =>
          current.copyWith(unavailableReasonDetail: value),
    );
  }

  void setVitalValue(VitalType type, double? value, {bool secondary = false}) {
    _updateVital(type, (VitalReadingDraft current) {
      if (value == null) {
        return secondary
            ? current.copyWith(secondaryValue: null)
            : current.copyWith(value: null);
      }
      final double normalized = _normalizeVitalValue(type, value);
      return secondary
          ? current.copyWith(secondaryValue: normalized)
          : current.copyWith(value: normalized);
    });
  }

  void setMeasuredAt(DateTime value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(measuredAt: value),
    );
  }

  void toggleTreatment(TreatmentType value) {
    _updateDraft((PatientAssessmentDraft draft) {
      if (value == TreatmentType.none) {
        return draft.copyWith(
          treatments: const <TreatmentType>{TreatmentType.none},
          treatmentEntries: const <TreatmentType, TreatmentEntryDraft>{},
        );
      }

      final Set<TreatmentType> updated = Set<TreatmentType>.of(draft.treatments)
        ..remove(TreatmentType.none);
      final Map<TreatmentType, TreatmentEntryDraft> entries =
          Map<TreatmentType, TreatmentEntryDraft>.of(draft.treatmentEntries);
      if (!updated.add(value)) {
        updated.remove(value);
        entries.remove(value);
      } else {
        entries.putIfAbsent(value, TreatmentEntryDraft.new);
      }
      return draft.copyWith(treatments: updated, treatmentEntries: entries);
    });
  }

  void setTreatmentAttemptResult(
    TreatmentType type,
    TreatmentAttemptResult value,
  ) {
    _updateTreatmentEntry(
      type,
      (TreatmentEntryDraft entry) => entry.copyWith(attemptResult: value),
    );
  }

  void setTreatmentDetail(TreatmentType type, String key, String value) {
    _updateTreatmentEntry(type, (TreatmentEntryDraft entry) {
      final Map<String, String> details = Map<String, String>.of(entry.details);
      details[key] = value;
      return entry.copyWith(details: details);
    });
  }

  void setPerformedAt(DateTime value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(performedAt: value),
    );
  }

  void toggleGlucose() {
    _updateDraft(
      (PatientAssessmentDraft draft) =>
          draft.copyWith(glucoseMgDl: draft.glucoseMgDl == null ? 85 : null),
    );
  }

  void setGlucose(int? value) {
    _updateDraft(
      (PatientAssessmentDraft draft) =>
          draft.copyWith(glucoseMgDl: value?.clamp(0, 1000)),
    );
  }

  void setLeftPupil(PupilResponse? value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(leftPupil: value),
    );
  }

  void setRightPupil(PupilResponse? value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(rightPupil: value),
    );
  }

  void setMedicalHistory(String value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(medicalHistory: value),
    );
  }

  void setAllergies(String value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(allergies: value),
    );
  }

  void setMedications(String value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(medications: value),
    );
  }

  void setIsolationConcern(bool? value) {
    _updateDraft(
      (PatientAssessmentDraft draft) => draft.copyWith(isolationConcern: value),
    );
  }

  Future<bool> nextStep() async {
    final PatientAssessmentViewState current = state.requireValue;
    final _AssessmentValidationIssue? issue = _validateStep(
      current.step,
      current.draft,
    );
    if (issue != null) {
      _setViewState(
        current.copyWith(
          errorMessage: issue.message,
          validationTarget: issue.target,
        ),
      );
      return false;
    }

    if (!current.isDraftReady) {
      _setViewState(
        current.copyWith(
          step: (current.step + 1).clamp(0, current.totalSteps - 1),
          clearError: true,
        ),
      );
      return true;
    }

    _setViewState(current.copyWith(isSaving: true, clearError: true));
    try {
      await ref.read(savePatientAssessmentDraftProvider)(current.draft);
      _setViewState(
        current.copyWith(
          step: (current.step + 1).clamp(0, current.totalSteps - 1),
          isSaving: false,
          clearError: true,
        ),
      );
      return true;
    } on AppException catch (error) {
      _setViewState(
        current.copyWith(isSaving: false, errorMessage: error.message),
      );
      return false;
    }
  }

  void previousStep() {
    final PatientAssessmentViewState current = state.requireValue;
    _setViewState(
      current.copyWith(
        step: (current.step - 1).clamp(0, current.totalSteps - 1),
        clearError: true,
      ),
    );
  }

  Future<TransferRequestReceipt?> submit() async {
    final PatientAssessmentViewState current = state.requireValue;
    if (!current.isDraftReady) {
      _setViewState(
        current.copyWith(
          errorMessage: current.isPreparingRequest
              ? '최신 GPS 위치를 확인하고 있습니다. 잠시만 기다려주세요.'
              : current.preparationErrorMessage ??
                    '전송 준비를 완료하지 못했습니다. 위치를 다시 확인해주세요.',
        ),
      );
      return null;
    }
    for (int step = 0; step < current.totalSteps; step++) {
      final _AssessmentValidationIssue? issue = _validateStep(
        step,
        current.draft,
      );
      if (issue != null) {
        _setViewState(
          current.copyWith(
            step: step,
            errorMessage: issue.message,
            validationTarget: issue.target,
          ),
        );
        return null;
      }
    }

    final PatientAssessmentDraft submissionDraft = current.draft;
    _setViewState(current.copyWith(isSubmitting: true, clearError: true));
    try {
      _draftSaveTimer?.cancel();
      await ref.read(savePatientAssessmentDraftProvider).call(submissionDraft);
      final TransferRequestReceipt receipt = await ref
          .read(submitTransferRequestProvider)
          .call(submissionDraft);
      await ref.read(clearPatientAssessmentDraftProvider).call();
      _setViewState(
        current.copyWith(
          isSubmitting: false,
          receipt: receipt,
          clearError: true,
        ),
      );
      return receipt;
    } on AppException catch (error) {
      _setViewState(
        current.copyWith(isSubmitting: false, errorMessage: error.message),
      );
      return null;
    } on Object {
      _setViewState(
        current.copyWith(
          isSubmitting: false,
          errorMessage: '이송 요청 정보를 안전하게 저장하지 못했습니다. 다시 시도해주세요.',
        ),
      );
      return null;
    }
  }

  Future<void> discardDraft() async {
    _isDiscarding = true;
    _draftSaveTimer?.cancel();
    await ref.read(clearPatientAssessmentDraftProvider).call();
  }

  void _updateVital(
    VitalType type,
    VitalReadingDraft Function(VitalReadingDraft current) update,
  ) {
    _updateDraft((PatientAssessmentDraft draft) {
      final Map<VitalType, VitalReadingDraft> vitals =
          Map<VitalType, VitalReadingDraft>.of(draft.vitals);
      final VitalReadingDraft current =
          vitals[type] ?? const VitalReadingDraft();
      vitals[type] = update(current);
      return draft.copyWith(vitals: vitals);
    });
  }

  void _updateTreatmentEntry(
    TreatmentType type,
    TreatmentEntryDraft Function(TreatmentEntryDraft entry) update,
  ) {
    _updateDraft((PatientAssessmentDraft draft) {
      final Map<TreatmentType, TreatmentEntryDraft> entries =
          Map<TreatmentType, TreatmentEntryDraft>.of(draft.treatmentEntries);
      entries[type] = update(entries[type] ?? const TreatmentEntryDraft());
      return draft.copyWith(treatmentEntries: entries);
    });
  }

  void _updateDraft(
    PatientAssessmentDraft Function(PatientAssessmentDraft draft) update,
  ) {
    final PatientAssessmentViewState current = state.requireValue;
    final PatientAssessmentDraft updated = update(current.draft);
    _hasUserEdits = true;
    _setViewState(current.copyWith(draft: updated, clearError: true));
    _draftSaveTimer?.cancel();
    if (!current.isDraftReady) {
      return;
    }
    _draftSaveTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(ref.read(savePatientAssessmentDraftProvider)(updated));
    });
  }

  void clearValidationMessage() {
    final PatientAssessmentViewState current = state.requireValue;
    if (current.validationTarget != null) {
      _setViewState(current.copyWith(clearError: true));
    }
  }

  bool isStepValid(int step, PatientAssessmentDraft draft) {
    return _validateStep(step, draft, requireOnsetTime: false) == null;
  }

  void _setViewState(PatientAssessmentViewState value) {
    state = AsyncValue<PatientAssessmentViewState>.data(value);
  }

  _AssessmentValidationIssue? _validateStep(
    int step,
    PatientAssessmentDraft draft, {
    bool requireOnsetTime = true,
  }) {
    switch (step) {
      case 0:
        if (draft.ageStatus == null) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.age,
            '나이 구분을 선택해주세요.',
          );
        }
        if (draft.ageStatus != AgeStatus.unknown && draft.ageYears == null) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.age,
            '나이를 입력하거나 확인 불가를 선택해주세요.',
          );
        }
        if (draft.sex == null) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.sex,
            '성별을 선택해주세요.',
          );
        }
        if (draft.occurrenceType == null) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.occurrenceType,
            '발생 유형을 선택해주세요.',
          );
        }
        if (draft.occurrenceType == OccurrenceType.other &&
            draft.occurrenceDetail.trim().isEmpty) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.occurrenceType,
            '발생 유형의 기타 상세를 입력해주세요.',
          );
        }
        if (draft.occurrenceType == OccurrenceType.nonDisease &&
            draft.mechanism == null) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.mechanism,
            '비질병·외상 환자의 손상 기전을 선택해주세요.',
          );
        }
        if (draft.occurrenceType == OccurrenceType.nonDisease &&
            draft.injurySites.isEmpty) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.injurySites,
            '비질병·외상 환자의 손상 부위를 선택해주세요.',
          );
        }
        if (requireOnsetTime && draft.onsetTimeStatus == null) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.onsetAt,
            '증상 발생 시각 구분을 선택해주세요.',
          );
        }
        if (requireOnsetTime &&
            draft.onsetTimeStatus != ClinicalTimeStatus.unknown &&
            draft.onsetAt == null) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.onsetAt,
            '증상 발생 시각을 입력해주세요.',
          );
        }
        return null;
      case 1:
        if (draft.primarySymptom == null) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.primarySymptom,
            '주증상을 선택해주세요.',
          );
        }
        if (draft.primarySymptom == PatientSymptom.other &&
            draft.primarySymptomDetail.trim().isEmpty) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.primarySymptom,
            '주증상의 기타 상세를 입력해주세요.',
          );
        }
        if (draft.classificationStatus == null) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.classification,
            '중증도 분류 방식을 선택해주세요.',
          );
        }
        if (draft.classificationStatus == ClassificationStatus.completed &&
            draft.preKtasLevel == null) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.preKtas,
            'Pre-KTAS 단계를 선택해주세요.',
          );
        }
        if (draft.classificationStatus ==
                ClassificationStatus.emergencyUnfinished &&
            draft.exceptionReason == null) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.exceptionReason,
            '긴급 전송 예외 사유를 선택해주세요.',
          );
        }
        if (draft.exceptionReason == EmergencyExceptionReason.other &&
            draft.exceptionDetail.trim().isEmpty) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.exceptionDetail,
            '긴급 전송 예외의 기타 사유를 입력해주세요.',
          );
        }
        if (draft.avpu == null) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.avpu,
            '의식 상태를 선택해주세요.',
          );
        }
        if (draft.avpu == AvpuLevel.unassessable &&
            draft.unassessableReason == null) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.unassessableReason,
            '의식 상태를 평가할 수 없는 사유를 선택해주세요.',
          );
        }
        if (draft.unassessableReason == UnassessableReason.other &&
            draft.unassessableDetail.trim().isEmpty) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.unassessableReason,
            '의식 평가 불가의 기타 상세를 입력해주세요.',
          );
        }
        return null;
      case 2:
        for (final VitalType type in VitalType.values) {
          final VitalReadingDraft? vital = draft.vitals[type];
          if (vital == null || vital.state == null) {
            return _AssessmentValidationIssue(
              validationTargetForVital(type),
              '${type.label} 값을 입력하거나 상태를 선택해주세요.',
            );
          }
          if (vital.state == MeasurementState.value && vital.value == null) {
            return _AssessmentValidationIssue(
              validationTargetForVital(type),
              '${type.label} 값을 입력해주세요.',
            );
          }
          if (type == VitalType.bloodPressure &&
              vital.state == MeasurementState.value &&
              vital.secondaryValue == null) {
            return const _AssessmentValidationIssue(
              AssessmentValidationTarget.bloodPressure,
              '이완기 혈압을 입력해주세요.',
            );
          }
          if (vital.state == MeasurementState.unavailable &&
              vital.unavailableReason == null) {
            return _AssessmentValidationIssue(
              validationTargetForVital(type),
              '${type.label} 측정 불가 사유를 선택해주세요.',
            );
          }
          if (vital.state == MeasurementState.unavailable &&
              vital.unavailableReason == MeasurementUnavailableReason.other &&
              vital.unavailableReasonDetail.trim().isEmpty) {
            return _AssessmentValidationIssue(
              validationTargetForVital(type),
              '${type.label} 측정 불가의 기타 사유를 입력해주세요.',
            );
          }
        }
        return null;
      case 3:
        if (draft.treatments.isEmpty) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.treatments,
            '처치 없음 또는 한 가지 이상의 처치를 선택해주세요.',
          );
        }
        if (draft.treatments.contains(TreatmentType.none) &&
            draft.treatments.length > 1) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.treatments,
            '처치 없음은 다른 처치와 함께 선택할 수 없습니다.',
          );
        }
        for (final TreatmentType type in draft.treatments.where(
          (TreatmentType value) => value != TreatmentType.none,
        )) {
          final TreatmentEntryDraft? entry = draft.treatmentEntries[type];
          if (entry?.attemptResult == null) {
            return _AssessmentValidationIssue(
              AssessmentValidationTarget.treatments,
              '${type.label}의 처치 결과를 선택해주세요.',
            );
          }
          final String? missingField = _missingTreatmentField(type, entry!);
          if (missingField != null) {
            return _AssessmentValidationIssue(
              AssessmentValidationTarget.treatments,
              '${type.label}의 $missingField 항목을 입력해주세요.',
            );
          }
        }
        if ((draft.leftPupil == null) != (draft.rightPupil == null)) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.pupils,
            '동공 반응은 좌우를 모두 입력해주세요.',
          );
        }
        if (draft.callbackContact.trim().isEmpty) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.callbackContact,
            '회원정보의 회신 연락처를 확인해주세요.',
          );
        }
        return null;
    }
    return const _AssessmentValidationIssue(
      AssessmentValidationTarget.callbackContact,
      '지원하지 않는 입력 단계입니다.',
    );
  }

  double _referenceVitalValue(VitalType type) {
    return switch (type) {
      VitalType.bloodPressure => 105.0,
      VitalType.pulse => 80.0,
      VitalType.respiratoryRate => 15.0,
      VitalType.temperature => 37.0,
      VitalType.oxygenSaturation => 98.0,
    };
  }

  String? _missingTreatmentField(
    TreatmentType type,
    TreatmentEntryDraft entry,
  ) {
    final List<MapEntry<String, String>> required = switch (type) {
      TreatmentType.oxygen => const <MapEntry<String, String>>[
        MapEntry<String, String>('method', '투여 방법'),
        MapEntry<String, String>('flowRateLpm', '유량(L/min)'),
      ],
      TreatmentType.airway => const <MapEntry<String, String>>[
        MapEntry<String, String>('device', '기도 확보 기구'),
      ],
      TreatmentType.cpr => const <MapEntry<String, String>>[
        MapEntry<String, String>('currentStatus', '현재 상태'),
      ],
      TreatmentType.defibrillationAed => const <MapEntry<String, String>>[
        MapEntry<String, String>('shockCount', '충격 횟수'),
      ],
      TreatmentType.ivFluid => const <MapEntry<String, String>>[
        MapEntry<String, String>('fluidName', '수액명'),
        MapEntry<String, String>('amountMl', '투여량(mL)'),
      ],
      TreatmentType.medication => const <MapEntry<String, String>>[
        MapEntry<String, String>('medicationName', '약물명'),
        MapEntry<String, String>('dose', '용량'),
        MapEntry<String, String>('route', '투여 경로'),
      ],
      TreatmentType.bleedingWound ||
      TreatmentType.immobilization => const <MapEntry<String, String>>[
        MapEntry<String, String>('method', '처치 방법'),
        MapEntry<String, String>('site', '처치 부위'),
      ],
      TreatmentType.ecg => const <MapEntry<String, String>>[
        MapEntry<String, String>('leadType', '리드 종류'),
      ],
      TreatmentType.warmingCooling => const <MapEntry<String, String>>[
        MapEntry<String, String>('method', '처치 방법'),
      ],
      TreatmentType.delivery => const <MapEntry<String, String>>[
        MapEntry<String, String>('currentStatus', '현재 상태'),
      ],
      TreatmentType.other => const <MapEntry<String, String>>[
        MapEntry<String, String>('detail', '상세 내용'),
      ],
      TreatmentType.none => const <MapEntry<String, String>>[],
    };
    for (final MapEntry<String, String> field in required) {
      if ((entry.details[field.key] ?? '').trim().isEmpty) {
        return field.value;
      }
    }
    return null;
  }

  double _normalizeVitalValue(VitalType type, double value) {
    final double nonNegative = value < 0 ? 0 : value;
    if (type == VitalType.oxygenSaturation && nonNegative > 100) {
      return 100;
    }
    return double.parse(nonNegative.toStringAsFixed(1));
  }
}

class PatientAssessmentViewState {
  const PatientAssessmentViewState({
    required this.draft,
    this.step = 0,
    this.isSaving = false,
    this.isSubmitting = false,
    this.isPreparingRequest = false,
    this.isDraftReady = true,
    this.preparationErrorMessage,
    this.errorMessage,
    this.validationTarget,
    this.receipt,
  });

  static const int totalStepCount = 4;

  final PatientAssessmentDraft draft;
  final int step;
  final bool isSaving;
  final bool isSubmitting;
  final bool isPreparingRequest;
  final bool isDraftReady;
  final String? preparationErrorMessage;
  final String? errorMessage;
  final AssessmentValidationTarget? validationTarget;
  final TransferRequestReceipt? receipt;

  int get totalSteps => totalStepCount;

  bool get isBusy => isSaving || isSubmitting;

  PatientAssessmentViewState copyWith({
    PatientAssessmentDraft? draft,
    int? step,
    bool? isSaving,
    bool? isSubmitting,
    bool? isPreparingRequest,
    bool? isDraftReady,
    String? preparationErrorMessage,
    String? errorMessage,
    AssessmentValidationTarget? validationTarget,
    TransferRequestReceipt? receipt,
    bool clearError = false,
    bool clearPreparationError = false,
  }) {
    return PatientAssessmentViewState(
      draft: draft ?? this.draft,
      step: step ?? this.step,
      isSaving: isSaving ?? this.isSaving,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isPreparingRequest: isPreparingRequest ?? this.isPreparingRequest,
      isDraftReady: isDraftReady ?? this.isDraftReady,
      preparationErrorMessage: clearPreparationError
          ? null
          : preparationErrorMessage ?? this.preparationErrorMessage,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      validationTarget: clearError
          ? null
          : validationTarget ?? this.validationTarget,
      receipt: receipt ?? this.receipt,
    );
  }
}

PatientAssessmentDraft _createPreparingDraft({
  required String callbackContact,
  required String clientRequestKey,
}) {
  final DateTime now = DateTime.now();
  return PatientAssessmentDraft(
    assessmentProtocolVersion: '',
    preKtasStandardVersion: '',
    clientRequestKey: clientRequestKey,
    sceneAddress: '현재 위치 확인 중',
    latitude: 0,
    longitude: 0,
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

class _AssessmentValidationIssue {
  const _AssessmentValidationIssue(this.target, this.message);

  final AssessmentValidationTarget target;
  final String message;
}
