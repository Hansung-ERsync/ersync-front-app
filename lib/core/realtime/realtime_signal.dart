enum RealtimeSignalKind { connected, update }

class RealtimeSignal {
  const RealtimeSignal({
    required this.kind,
    this.eventId,
    this.type,
    this.aggregateType,
    this.aggregateId,
    this.occurredAt,
  });

  const RealtimeSignal.connected() : this(kind: RealtimeSignalKind.connected);

  final RealtimeSignalKind kind;
  final String? eventId;
  final String? type;
  final String? aggregateType;
  final String? aggregateId;
  final DateTime? occurredAt;
}
