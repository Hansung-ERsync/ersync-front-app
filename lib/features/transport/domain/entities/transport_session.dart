import '../../../hospital_search/domain/entities/accepted_hospital.dart';
import 'patient_transport_summary.dart';

class TransportSession {
  const TransportSession({
    required this.requestId,
    required this.requestStartedAt,
    required this.destination,
    required this.patientSummary,
    this.requestStatus = 'EN_ROUTE',
  });

  final String requestId;
  final DateTime requestStartedAt;
  final AcceptedHospital destination;
  final PatientTransportSummary patientSummary;
  final String requestStatus;

  bool get canSendLocation => requestStatus == 'EN_ROUTE';
  bool get isHandoffPending => requestStatus == 'HANDOFF_REQUESTED';
}
