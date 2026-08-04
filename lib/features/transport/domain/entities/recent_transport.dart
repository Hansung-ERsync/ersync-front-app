enum HandoffStatus { requested, completed }

class RecentTransport {
  const RecentTransport({
    required this.requestId,
    required this.hospitalName,
    required this.statusUpdatedAt,
    required this.handoffStatus,
  });

  final String requestId;
  final String hospitalName;
  final DateTime statusUpdatedAt;
  final HandoffStatus handoffStatus;

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
