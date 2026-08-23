class RealtimeSignal {
  const RealtimeSignal({this.eventId, this.type, this.aggregateId});

  const RealtimeSignal.connected()
    : eventId = null,
      type = null,
      aggregateId = null;

  final String? eventId;
  final String? type;
  final String? aggregateId;
}
