import 'accepted_hospital.dart';

class HospitalSearchProgress {
  const HospitalSearchProgress({
    required this.requestId,
    required this.currentRadiusKm,
    required this.elapsedSeconds,
    this.requestStatus = 'SEARCHING',
    this.isElapsedRunning = true,
    this.expansionRemainingSeconds,
    this.nextExpansionAt,
    this.candidateShortage = false,
    this.exhaustionReason,
    this.acceptedHospitals = const <AcceptedHospital>[],
  });

  final String requestId;
  final int currentRadiusKm;
  final int elapsedSeconds;
  final String requestStatus;
  final bool isElapsedRunning;
  final int? expansionRemainingSeconds;
  final DateTime? nextExpansionAt;
  final bool candidateShortage;
  final String? exhaustionReason;
  final List<AcceptedHospital> acceptedHospitals;

  bool get isCancelled => requestStatus == 'CANCELLED';
  bool get isExhausted => requestStatus == 'CANDIDATES_EXHAUSTED';
  bool get isSearching => requestStatus == 'SEARCHING';
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

class TransportCancellation {
  const TransportCancellation({required this.reason, this.detail});

  final TransportCancellationReason reason;
  final String? detail;

  String? get normalizedDetail {
    if (reason != TransportCancellationReason.other) {
      return null;
    }
    final String value = detail?.trim() ?? '';
    return value.isEmpty ? null : value;
  }
}
