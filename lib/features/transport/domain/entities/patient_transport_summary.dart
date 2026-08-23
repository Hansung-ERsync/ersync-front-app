class PatientTransportSummary {
  const PatientTransportSummary({
    required this.ageLabel,
    required this.sexLabel,
    required this.primarySymptomLabel,
    required this.preKtasLabel,
    required this.avpuLabel,
    this.preKtasStandardVersion = 'DEV_UNCONFIRMED',
    this.systolic,
    this.diastolic,
    this.pulse,
    this.respiratoryRate,
    this.temperature,
    this.oxygenSaturation,
    this.vitalsMeasuredAt,
    this.bloodPressureStateLabel = '확인 불가',
    this.pulseStateLabel = '확인 불가',
    this.respiratoryRateStateLabel = '확인 불가',
    this.temperatureStateLabel = '확인 불가',
    this.oxygenSaturationStateLabel = '확인 불가',
    this.glucoseMgDl,
    this.leftPupilLabel,
    this.rightPupilLabel,
    this.medicalHistory,
    this.allergies,
    this.medications,
    this.isolationConcern,
    this.supplementalAssessedAt,
    this.occurrenceLabel,
    this.occurrenceDetail,
    this.injuryMechanismLabel,
    this.injurySitesLabel,
    this.primarySymptomDetail,
    this.secondarySymptomsLabel,
    this.onsetLabel,
    this.preKtasDetailLabel,
    this.consciousnessDetailLabel,
    this.latestTreatmentLabel,
    this.latestTreatmentAt,
    this.lastClinicalUpdateAt,
  });

  const PatientTransportSummary.empty()
    : ageLabel = '확인 불가',
      sexLabel = '확인 불가',
      primarySymptomLabel = '확인 불가',
      preKtasLabel = '분류 확인 중',
      avpuLabel = '확인 불가',
      preKtasStandardVersion = 'DEV_UNCONFIRMED',
      systolic = null,
      diastolic = null,
      pulse = null,
      respiratoryRate = null,
      temperature = null,
      oxygenSaturation = null,
      vitalsMeasuredAt = null,
      bloodPressureStateLabel = '확인 불가',
      pulseStateLabel = '확인 불가',
      respiratoryRateStateLabel = '확인 불가',
      temperatureStateLabel = '확인 불가',
      oxygenSaturationStateLabel = '확인 불가',
      glucoseMgDl = null,
      leftPupilLabel = null,
      rightPupilLabel = null,
      medicalHistory = null,
      allergies = null,
      medications = null,
      isolationConcern = null,
      supplementalAssessedAt = null,
      occurrenceLabel = null,
      occurrenceDetail = null,
      injuryMechanismLabel = null,
      injurySitesLabel = null,
      primarySymptomDetail = null,
      secondarySymptomsLabel = null,
      onsetLabel = null,
      preKtasDetailLabel = null,
      consciousnessDetailLabel = null,
      latestTreatmentLabel = null,
      latestTreatmentAt = null,
      lastClinicalUpdateAt = null;

  final String ageLabel;
  final String sexLabel;
  final String primarySymptomLabel;
  final String preKtasLabel;
  final String avpuLabel;
  final String preKtasStandardVersion;
  final double? systolic;
  final double? diastolic;
  final double? pulse;
  final double? respiratoryRate;
  final double? temperature;
  final double? oxygenSaturation;
  final DateTime? vitalsMeasuredAt;
  final String bloodPressureStateLabel;
  final String pulseStateLabel;
  final String respiratoryRateStateLabel;
  final String temperatureStateLabel;
  final String oxygenSaturationStateLabel;
  final int? glucoseMgDl;
  final String? leftPupilLabel;
  final String? rightPupilLabel;
  final String? medicalHistory;
  final String? allergies;
  final String? medications;
  final bool? isolationConcern;
  final DateTime? supplementalAssessedAt;
  final String? occurrenceLabel;
  final String? occurrenceDetail;
  final String? injuryMechanismLabel;
  final String? injurySitesLabel;
  final String? primarySymptomDetail;
  final String? secondarySymptomsLabel;
  final String? onsetLabel;
  final String? preKtasDetailLabel;
  final String? consciousnessDetailLabel;
  final String? latestTreatmentLabel;
  final DateTime? latestTreatmentAt;
  final DateTime? lastClinicalUpdateAt;

  bool get hasIncidentDetails =>
      occurrenceLabel != null ||
      occurrenceDetail != null ||
      injuryMechanismLabel != null ||
      injurySitesLabel != null ||
      primarySymptomDetail != null ||
      secondarySymptomsLabel != null ||
      onsetLabel != null;

  bool get hasSupplementalAssessment =>
      glucoseMgDl != null ||
      leftPupilLabel != null ||
      rightPupilLabel != null ||
      medicalHistory != null ||
      allergies != null ||
      medications != null ||
      isolationConcern != null;

  String get bloodPressureDisplay => systolic == null || diastolic == null
      ? bloodPressureStateLabel
      : '${systolic!.round()}/${diastolic!.round()} mmHg';

  String get pulseDisplay =>
      pulse == null ? pulseStateLabel : '${pulse!.round()} bpm';

  String get respiratoryRateDisplay => respiratoryRate == null
      ? respiratoryRateStateLabel
      : '${respiratoryRate!.round()} /min';

  String get temperatureDisplay => temperature == null
      ? temperatureStateLabel
      : '${temperature!.toStringAsFixed(1)}°C';

  String get oxygenSaturationDisplay => oxygenSaturation == null
      ? oxygenSaturationStateLabel
      : '${oxygenSaturation!.round()} %';

  PatientTransportSummary copyWithVitals({
    required double systolic,
    required double diastolic,
    required double pulse,
    required double respiratoryRate,
    required double temperature,
    required double oxygenSaturation,
    required DateTime measuredAt,
    DateTime? lastClinicalUpdateAt,
  }) {
    return PatientTransportSummary(
      ageLabel: ageLabel,
      sexLabel: sexLabel,
      primarySymptomLabel: primarySymptomLabel,
      preKtasLabel: preKtasLabel,
      avpuLabel: avpuLabel,
      preKtasStandardVersion: preKtasStandardVersion,
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
      respiratoryRate: respiratoryRate,
      temperature: temperature,
      oxygenSaturation: oxygenSaturation,
      vitalsMeasuredAt: measuredAt,
      bloodPressureStateLabel: bloodPressureStateLabel,
      pulseStateLabel: pulseStateLabel,
      respiratoryRateStateLabel: respiratoryRateStateLabel,
      temperatureStateLabel: temperatureStateLabel,
      oxygenSaturationStateLabel: oxygenSaturationStateLabel,
      glucoseMgDl: glucoseMgDl,
      leftPupilLabel: leftPupilLabel,
      rightPupilLabel: rightPupilLabel,
      medicalHistory: medicalHistory,
      allergies: allergies,
      medications: medications,
      isolationConcern: isolationConcern,
      supplementalAssessedAt: supplementalAssessedAt,
      occurrenceLabel: occurrenceLabel,
      occurrenceDetail: occurrenceDetail,
      injuryMechanismLabel: injuryMechanismLabel,
      injurySitesLabel: injurySitesLabel,
      primarySymptomDetail: primarySymptomDetail,
      secondarySymptomsLabel: secondarySymptomsLabel,
      onsetLabel: onsetLabel,
      preKtasDetailLabel: preKtasDetailLabel,
      consciousnessDetailLabel: consciousnessDetailLabel,
      latestTreatmentLabel: latestTreatmentLabel,
      latestTreatmentAt: latestTreatmentAt,
      lastClinicalUpdateAt: lastClinicalUpdateAt ?? this.lastClinicalUpdateAt,
    );
  }

  PatientTransportSummary copyWithConsciousness({required String avpuLabel}) {
    return _copyWith(avpuLabel: avpuLabel);
  }

  PatientTransportSummary copyWithPreKtas({required String preKtasLabel}) {
    return _copyWith(preKtasLabel: preKtasLabel);
  }

  PatientTransportSummary copyWithLastClinicalUpdateAt(DateTime? value) {
    return _copyWith(lastClinicalUpdateAt: value);
  }

  PatientTransportSummary _copyWith({
    String? preKtasLabel,
    String? avpuLabel,
    DateTime? lastClinicalUpdateAt,
  }) {
    return PatientTransportSummary(
      ageLabel: ageLabel,
      sexLabel: sexLabel,
      primarySymptomLabel: primarySymptomLabel,
      preKtasLabel: preKtasLabel ?? this.preKtasLabel,
      avpuLabel: avpuLabel ?? this.avpuLabel,
      preKtasStandardVersion: preKtasStandardVersion,
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
      respiratoryRate: respiratoryRate,
      temperature: temperature,
      oxygenSaturation: oxygenSaturation,
      vitalsMeasuredAt: vitalsMeasuredAt,
      bloodPressureStateLabel: bloodPressureStateLabel,
      pulseStateLabel: pulseStateLabel,
      respiratoryRateStateLabel: respiratoryRateStateLabel,
      temperatureStateLabel: temperatureStateLabel,
      oxygenSaturationStateLabel: oxygenSaturationStateLabel,
      glucoseMgDl: glucoseMgDl,
      leftPupilLabel: leftPupilLabel,
      rightPupilLabel: rightPupilLabel,
      medicalHistory: medicalHistory,
      allergies: allergies,
      medications: medications,
      isolationConcern: isolationConcern,
      supplementalAssessedAt: supplementalAssessedAt,
      occurrenceLabel: occurrenceLabel,
      occurrenceDetail: occurrenceDetail,
      injuryMechanismLabel: injuryMechanismLabel,
      injurySitesLabel: injurySitesLabel,
      primarySymptomDetail: primarySymptomDetail,
      secondarySymptomsLabel: secondarySymptomsLabel,
      onsetLabel: onsetLabel,
      preKtasDetailLabel: preKtasDetailLabel,
      consciousnessDetailLabel: consciousnessDetailLabel,
      latestTreatmentLabel: latestTreatmentLabel,
      latestTreatmentAt: latestTreatmentAt,
      lastClinicalUpdateAt: lastClinicalUpdateAt ?? this.lastClinicalUpdateAt,
    );
  }
}
