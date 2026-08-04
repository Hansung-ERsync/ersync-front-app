class TransferRequestReceipt {
  const TransferRequestReceipt({
    required this.requestId,
    required this.status,
    required this.protocolVersion,
    required this.createdAt,
    required this.currentSearchRadiusKm,
    required this.radiusStepKm,
    required this.expansionIntervalSeconds,
    required this.maximumSearchRadiusKm,
  });

  final String requestId;
  final String status;
  final String protocolVersion;
  final DateTime createdAt;
  final int currentSearchRadiusKm;
  final int radiusStepKm;
  final int expansionIntervalSeconds;
  final int maximumSearchRadiusKm;
}
