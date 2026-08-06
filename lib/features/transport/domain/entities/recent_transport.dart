enum HandoffStatus { requested, completed, cancelled }

class RecentTransport {
  const RecentTransport({
    required this.requestId,
    required this.hospitalName,
    required this.statusUpdatedAt,
    required this.handoffStatus,
  });

  final String requestId;
  final String? hospitalName;
  final DateTime statusUpdatedAt;
  final HandoffStatus handoffStatus;

  String get hospitalDisplayName =>
      hospitalName?.trim().isNotEmpty == true ? hospitalName!.trim() : '목적지 미정';

  bool get hasDestination => hospitalName?.trim().isNotEmpty == true;

  RecentTransport copyWith({
    DateTime? statusUpdatedAt,
    HandoffStatus? handoffStatus,
  }) {
    return RecentTransport(
      requestId: requestId,
      hospitalName: hospitalName,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
      handoffStatus: handoffStatus ?? this.handoffStatus,
    );
  }
}
