import 'accepted_hospital.dart';

class HospitalSearchProgress {
  const HospitalSearchProgress({
    required this.requestId,
    required this.currentRadiusKm,
    required this.elapsedSeconds,
    this.acceptedHospitals = const <AcceptedHospital>[],
  });

  final String requestId;
  final int currentRadiusKm;
  final int elapsedSeconds;
  final List<AcceptedHospital> acceptedHospitals;
}

enum TransportCancellationReason {
  patientRefusedTransport('환자 이송 거부', 'PATIENT_REFUSED_TRANSPORT'),
  guardianSelfTransport('보호자 자체 이송', 'GUARDIAN_SELF_TRANSPORT'),
  sceneResolved('현장 상황 종료', 'SCENE_RESOLVED'),
  other('기타', 'OTHER');

  const TransportCancellationReason(this.label, this.apiValue);

  final String label;
  final String apiValue;
}
