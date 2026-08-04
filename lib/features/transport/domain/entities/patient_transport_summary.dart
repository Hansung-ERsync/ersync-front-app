class PatientTransportSummary {
  const PatientTransportSummary({
    required this.ageLabel,
    required this.sexLabel,
    required this.primarySymptomLabel,
    required this.preKtasLabel,
    required this.avpuLabel,
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
  });

  const PatientTransportSummary.empty()
    : ageLabel = '확인 불가',
      sexLabel = '확인 불가',
      primarySymptomLabel = '확인 불가',
      preKtasLabel = '분류 확인 중',
      avpuLabel = '확인 불가',
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
      oxygenSaturationStateLabel = '확인 불가';

  final String ageLabel;
  final String sexLabel;
  final String primarySymptomLabel;
  final String preKtasLabel;
  final String avpuLabel;
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
  }) {
    return PatientTransportSummary(
      ageLabel: ageLabel,
      sexLabel: sexLabel,
      primarySymptomLabel: primarySymptomLabel,
      preKtasLabel: preKtasLabel,
      avpuLabel: avpuLabel,
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
    );
  }
}
