class InTransitVitalUpdate {
  const InTransitVitalUpdate({
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.respiratoryRate,
    required this.temperature,
    required this.oxygenSaturation,
    required this.measuredAt,
  });

  final double systolic;
  final double diastolic;
  final double pulse;
  final double respiratoryRate;
  final double temperature;
  final double oxygenSaturation;
  final DateTime measuredAt;
}
