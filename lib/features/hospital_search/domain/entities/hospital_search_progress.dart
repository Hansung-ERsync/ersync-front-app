import 'accepted_hospital.dart';
import 'hospital_response.dart';

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
    this.currentDestinationOfferId,
    this.currentAttemptTriggerType,
    this.acceptedHospitals = const <AcceptedHospital>[],
    this.pendingHospitals = const <HospitalResponse>[],
    this.rejectedHospitals = const <HospitalResponse>[],
    this.withdrawnHospitals = const <HospitalResponse>[],
  });

  final String requestId;
  final int currentRadiusKm;
  final int elapsedSeconds;
  final String requestStatus;
  final bool isElapsedRunning;
  final int? expansionRemainingSeconds;
  final DateTime? nextExpansionAt;
  final bool candidateShortage;
  final String? currentDestinationOfferId;
  final String? currentAttemptTriggerType;
  final List<AcceptedHospital> acceptedHospitals;
  final List<HospitalResponse> pendingHospitals;
  final List<HospitalResponse> rejectedHospitals;
  final List<HospitalResponse> withdrawnHospitals;

  bool get isCancelled => requestStatus == 'CANCELLED';
  bool get isSearching => requestStatus == 'SEARCHING';
  bool get isWithdrawalRecovery =>
      currentDestinationOfferId == null &&
      currentAttemptTriggerType == 'ACCEPTANCE_WITHDRAWAL';
  bool get hasResponseDashboard =>
      acceptedHospitals.isNotEmpty ||
      withdrawnHospitals.isNotEmpty ||
      isWithdrawalRecovery;
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
