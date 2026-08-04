import '../../../transport/domain/entities/patient_transport_summary.dart';

class HospitalSearchSession {
  const HospitalSearchSession({
    required this.requestId,
    required this.startedAt,
    required this.initialRadiusKm,
    required this.radiusStepKm,
    required this.expansionIntervalSeconds,
    required this.maximumRadiusKm,
    this.patientSummary = const PatientTransportSummary.empty(),
  });

  final String requestId;
  final DateTime startedAt;
  final int initialRadiusKm;
  final int radiusStepKm;
  final int expansionIntervalSeconds;
  final int maximumRadiusKm;
  final PatientTransportSummary patientSummary;
}
