class ClinicalUpdateResult {
  const ClinicalUpdateResult({
    required this.snapshotUpdated,
    this.lastClinicalUpdateAt,
  });

  final bool snapshotUpdated;
  final DateTime? lastClinicalUpdateAt;
}
