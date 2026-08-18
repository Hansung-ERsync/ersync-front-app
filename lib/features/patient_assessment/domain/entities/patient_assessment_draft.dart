import 'assessment_enums.dart';

const Object _notProvided = Object();

class VitalReadingDraft {
  const VitalReadingDraft({
    this.state,
    this.value,
    this.secondaryValue,
    this.unavailableReason,
    this.unavailableReasonDetail = '',
  });

  final MeasurementState? state;
  final double? value;
  final double? secondaryValue;
  final MeasurementUnavailableReason? unavailableReason;
  final String unavailableReasonDetail;

  VitalReadingDraft copyWith({
    MeasurementState? state,
    Object? value = _notProvided,
    Object? secondaryValue = _notProvided,
    Object? unavailableReason = _notProvided,
    String? unavailableReasonDetail,
  }) {
    return VitalReadingDraft(
      state: state ?? this.state,
      value: identical(value, _notProvided) ? this.value : value as double?,
      secondaryValue: identical(secondaryValue, _notProvided)
          ? this.secondaryValue
          : secondaryValue as double?,
      unavailableReason: identical(unavailableReason, _notProvided)
          ? this.unavailableReason
          : unavailableReason as MeasurementUnavailableReason?,
      unavailableReasonDetail:
          unavailableReasonDetail ?? this.unavailableReasonDetail,
    );
  }
}

class TreatmentEntryDraft {
  const TreatmentEntryDraft({
    this.attemptResult,
    this.details = const <String, String>{},
  });

  final TreatmentAttemptResult? attemptResult;
  final Map<String, String> details;

  TreatmentEntryDraft copyWith({
    TreatmentAttemptResult? attemptResult,
    Map<String, String>? details,
  }) {
    return TreatmentEntryDraft(
      attemptResult: attemptResult ?? this.attemptResult,
      details: Map<String, String>.unmodifiable(details ?? this.details),
    );
  }
}

class PatientAssessmentDraft {
  const PatientAssessmentDraft({
    required this.assessmentProtocolVersion,
    required this.preKtasStandardVersion,
    required this.clientRequestKey,
    required this.sceneAddress,
    required this.latitude,
    required this.longitude,
    required this.locationSource,
    required this.callbackContact,
    required this.ageStatus,
    required this.ageYears,
    required this.sex,
    required this.occurrenceType,
    required this.occurrenceDetail,
    required this.mechanism,
    required this.injurySites,
    required this.primarySymptom,
    required this.primarySymptomDetail,
    required this.secondarySymptoms,
    required this.onsetTimeStatus,
    required this.onsetAt,
    required this.classificationStatus,
    required this.preKtasLevel,
    required this.exceptionReason,
    required this.exceptionDetail,
    required this.avpu,
    required this.unassessableReason,
    required this.unassessableDetail,
    required this.assessedAt,
    required this.observedAt,
    required this.vitals,
    required this.measuredAt,
    required this.treatments,
    required this.treatmentEntries,
    required this.performedAt,
    required this.glucoseMgDl,
    required this.leftPupil,
    required this.rightPupil,
    required this.medicalHistory,
    required this.allergies,
    required this.medications,
    required this.isolationConcern,
    required this.enteredAt,
  });

  final String assessmentProtocolVersion;
  final String preKtasStandardVersion;
  final String clientRequestKey;
  final String sceneAddress;
  final double latitude;
  final double longitude;
  final String locationSource;
  final String callbackContact;

  final AgeStatus? ageStatus;
  final int? ageYears;
  final PatientSex? sex;
  final OccurrenceType? occurrenceType;
  final String occurrenceDetail;
  final InjuryMechanism? mechanism;
  final Set<InjurySite> injurySites;
  final PatientSymptom? primarySymptom;
  final String primarySymptomDetail;
  final Set<PatientSymptom> secondarySymptoms;
  final ClinicalTimeStatus? onsetTimeStatus;
  final DateTime? onsetAt;

  final ClassificationStatus? classificationStatus;
  final int? preKtasLevel;
  final EmergencyExceptionReason? exceptionReason;
  final String exceptionDetail;
  final AvpuLevel? avpu;
  final UnassessableReason? unassessableReason;
  final String unassessableDetail;
  final DateTime assessedAt;
  final DateTime observedAt;

  final Map<VitalType, VitalReadingDraft> vitals;
  final DateTime measuredAt;
  final Set<TreatmentType> treatments;
  final Map<TreatmentType, TreatmentEntryDraft> treatmentEntries;
  final DateTime performedAt;

  final int? glucoseMgDl;
  final PupilResponse? leftPupil;
  final PupilResponse? rightPupil;
  final String medicalHistory;
  final String allergies;
  final String medications;
  final bool? isolationConcern;
  final DateTime enteredAt;

  PatientAssessmentDraft copyWith({
    String? assessmentProtocolVersion,
    String? preKtasStandardVersion,
    String? clientRequestKey,
    String? sceneAddress,
    double? latitude,
    double? longitude,
    String? locationSource,
    String? callbackContact,
    AgeStatus? ageStatus,
    Object? ageYears = _notProvided,
    PatientSex? sex,
    OccurrenceType? occurrenceType,
    String? occurrenceDetail,
    Object? mechanism = _notProvided,
    Set<InjurySite>? injurySites,
    Object? primarySymptom = _notProvided,
    String? primarySymptomDetail,
    Set<PatientSymptom>? secondarySymptoms,
    ClinicalTimeStatus? onsetTimeStatus,
    Object? onsetAt = _notProvided,
    ClassificationStatus? classificationStatus,
    Object? preKtasLevel = _notProvided,
    Object? exceptionReason = _notProvided,
    String? exceptionDetail,
    Object? avpu = _notProvided,
    Object? unassessableReason = _notProvided,
    String? unassessableDetail,
    DateTime? assessedAt,
    DateTime? observedAt,
    Map<VitalType, VitalReadingDraft>? vitals,
    DateTime? measuredAt,
    Set<TreatmentType>? treatments,
    Map<TreatmentType, TreatmentEntryDraft>? treatmentEntries,
    DateTime? performedAt,
    Object? glucoseMgDl = _notProvided,
    Object? leftPupil = _notProvided,
    Object? rightPupil = _notProvided,
    String? medicalHistory,
    String? allergies,
    String? medications,
    Object? isolationConcern = _notProvided,
    DateTime? enteredAt,
  }) {
    return PatientAssessmentDraft(
      assessmentProtocolVersion:
          assessmentProtocolVersion ?? this.assessmentProtocolVersion,
      preKtasStandardVersion:
          preKtasStandardVersion ?? this.preKtasStandardVersion,
      clientRequestKey: clientRequestKey ?? this.clientRequestKey,
      sceneAddress: sceneAddress ?? this.sceneAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationSource: locationSource ?? this.locationSource,
      callbackContact: callbackContact ?? this.callbackContact,
      ageStatus: ageStatus ?? this.ageStatus,
      ageYears: identical(ageYears, _notProvided)
          ? this.ageYears
          : ageYears as int?,
      sex: sex ?? this.sex,
      occurrenceType: occurrenceType ?? this.occurrenceType,
      occurrenceDetail: occurrenceDetail ?? this.occurrenceDetail,
      mechanism: identical(mechanism, _notProvided)
          ? this.mechanism
          : mechanism as InjuryMechanism?,
      injurySites: Set<InjurySite>.unmodifiable(
        injurySites ?? this.injurySites,
      ),
      primarySymptom: identical(primarySymptom, _notProvided)
          ? this.primarySymptom
          : primarySymptom as PatientSymptom?,
      primarySymptomDetail: primarySymptomDetail ?? this.primarySymptomDetail,
      secondarySymptoms: Set<PatientSymptom>.unmodifiable(
        secondarySymptoms ?? this.secondarySymptoms,
      ),
      onsetTimeStatus: onsetTimeStatus ?? this.onsetTimeStatus,
      onsetAt: identical(onsetAt, _notProvided)
          ? this.onsetAt
          : onsetAt as DateTime?,
      classificationStatus: classificationStatus ?? this.classificationStatus,
      preKtasLevel: identical(preKtasLevel, _notProvided)
          ? this.preKtasLevel
          : preKtasLevel as int?,
      exceptionReason: identical(exceptionReason, _notProvided)
          ? this.exceptionReason
          : exceptionReason as EmergencyExceptionReason?,
      exceptionDetail: exceptionDetail ?? this.exceptionDetail,
      avpu: identical(avpu, _notProvided) ? this.avpu : avpu as AvpuLevel?,
      unassessableReason: identical(unassessableReason, _notProvided)
          ? this.unassessableReason
          : unassessableReason as UnassessableReason?,
      unassessableDetail: unassessableDetail ?? this.unassessableDetail,
      assessedAt: assessedAt ?? this.assessedAt,
      observedAt: observedAt ?? this.observedAt,
      vitals: Map<VitalType, VitalReadingDraft>.unmodifiable(
        vitals ?? this.vitals,
      ),
      measuredAt: measuredAt ?? this.measuredAt,
      treatments: Set<TreatmentType>.unmodifiable(
        treatments ?? this.treatments,
      ),
      treatmentEntries: Map<TreatmentType, TreatmentEntryDraft>.unmodifiable(
        treatmentEntries ?? this.treatmentEntries,
      ),
      performedAt: performedAt ?? this.performedAt,
      glucoseMgDl: identical(glucoseMgDl, _notProvided)
          ? this.glucoseMgDl
          : glucoseMgDl as int?,
      leftPupil: identical(leftPupil, _notProvided)
          ? this.leftPupil
          : leftPupil as PupilResponse?,
      rightPupil: identical(rightPupil, _notProvided)
          ? this.rightPupil
          : rightPupil as PupilResponse?,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      allergies: allergies ?? this.allergies,
      medications: medications ?? this.medications,
      isolationConcern: identical(isolationConcern, _notProvided)
          ? this.isolationConcern
          : isolationConcern as bool?,
      enteredAt: enteredAt ?? this.enteredAt,
    );
  }
}
