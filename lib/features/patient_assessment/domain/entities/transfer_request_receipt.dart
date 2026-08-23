class TransferRequestReceipt {
  const TransferRequestReceipt({
    required this.requestId,
    required this.createdAt,
    required this.currentSearchRadiusKm,
    required this.radiusStepKm,
    required this.expansionIntervalSeconds,
    required this.maximumSearchRadiusKm,
  });

  final String requestId;
  final DateTime createdAt;
  final int currentSearchRadiusKm;
  final int radiusStepKm;
  final int expansionIntervalSeconds;
  final int maximumSearchRadiusKm;
}
