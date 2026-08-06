class PrivacyConsentRecord {
  const PrivacyConsentRecord({
    required this.collectionUseVersion,
    required this.hospitalProvisionVersion,
    required this.acceptedAt,
    this.legacyCombined = false,
  });

  final String collectionUseVersion;
  final String hospitalProvisionVersion;
  final DateTime acceptedAt;
  final bool legacyCombined;
}
