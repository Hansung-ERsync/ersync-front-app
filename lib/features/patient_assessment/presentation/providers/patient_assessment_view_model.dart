import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/data/datasources/mock_auth_data_source.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_view_model.dart';
import '../../data/datasources/mock_patient_assessment_data_source.dart';
import '../../data/repositories/mock_patient_assessment_repository.dart';
import '../../domain/entities/assessment_enums.dart';
import '../../domain/entities/patient_assessment_draft.dart';
import '../../domain/entities/transfer_request_receipt.dart';
import '../../domain/repositories/patient_assessment_repository.dart';
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
    AsyncNotifierProvider<
      PatientAssessmentViewModel,
      PatientAssessmentViewState
    >(PatientAssessmentViewModel.new);

class PatientAssessmentViewModel
    extends AsyncNotifier<PatientAssessmentViewState> {
  @override
  Future<PatientAssessmentViewState> build() async {
    final PatientAssessmentDraft draft = await ref
        .watch(loadPatientAssessmentDraftProvider)
        .call();
    return PatientAssessmentViewState(draft: draft);
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
        mechanism: value == OccurrenceType.nonDisease ? draft.mechanism : null,
        injurySites: value == OccurrenceType.nonDisease
            ? draft.injurySites
            : const <InjurySite>{},
      ),
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

  void setPrimarySymptom(PatientSymptom value) {
    _updateDraft((PatientAssessmentDraft draft) {
      final Set<PatientSymptom> secondary = Set<PatientSymptom>.of(
        draft.secondarySymptoms,
      )..remove(value);
      return draft.copyWith(
        primarySymptom: value,
        secondarySymptoms: secondary,
      );
    });
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
      ),
    );
  }

  void setUnassessableReason(UnassessableReason value) {
    _updateDraft(
      (PatientAssessmentDraft draft) =>
          draft.copyWith(unassessableReason: value),
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
        );
      }

      final Set<TreatmentType> updated = Set<TreatmentType>.of(draft.treatments)
        ..remove(TreatmentType.none);
      if (!updated.add(value)) {
        updated.remove(value);
      }
      return draft.copyWith(treatments: updated);
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

    _setViewState(current.copyWith(isSubmitting: true, clearError: true));
    try {
      final TransferRequestReceipt receipt = await ref
          .read(submitTransferRequestProvider)
          .call(current.draft);
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
    }
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

  void _updateDraft(
    PatientAssessmentDraft Function(PatientAssessmentDraft draft) update,
  ) {
    final PatientAssessmentViewState current = state.requireValue;
    _setViewState(
      current.copyWith(draft: update(current.draft), clearError: true),
    );
  }

  void clearValidationMessage() {
    final PatientAssessmentViewState current = state.requireValue;
    if (current.validationTarget != null) {
      _setViewState(current.copyWith(clearError: true));
    }
  }

  bool isStepValid(int step, PatientAssessmentDraft draft) {
    return _validateStep(step, draft) == null;
  }

  void _setViewState(PatientAssessmentViewState value) {
    state = AsyncValue<PatientAssessmentViewState>.data(value);
  }

  _AssessmentValidationIssue? _validateStep(
    int step,
    PatientAssessmentDraft draft,
  ) {
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
        if (draft.onsetTimeStatus == null) {
          return const _AssessmentValidationIssue(
            AssessmentValidationTarget.onsetAt,
            '증상 발생 시각 구분을 선택해주세요.',
          );
        }
        if (draft.onsetTimeStatus != ClinicalTimeStatus.unknown &&
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
    this.errorMessage,
    this.validationTarget,
    this.receipt,
  });

  static const int totalStepCount = 4;

  final PatientAssessmentDraft draft;
  final int step;
  final bool isSaving;
  final bool isSubmitting;
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
    String? errorMessage,
    AssessmentValidationTarget? validationTarget,
    TransferRequestReceipt? receipt,
    bool clearError = false,
  }) {
    return PatientAssessmentViewState(
      draft: draft ?? this.draft,
      step: step ?? this.step,
      isSaving: isSaving ?? this.isSaving,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      validationTarget: clearError
          ? null
          : validationTarget ?? this.validationTarget,
      receipt: receipt ?? this.receipt,
    );
  }
}

class _AssessmentValidationIssue {
  const _AssessmentValidationIssue(this.target, this.message);

  final AssessmentValidationTarget target;
  final String message;
}
