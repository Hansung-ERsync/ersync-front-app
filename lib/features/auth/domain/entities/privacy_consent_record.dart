class PrivacyConsentRecord {
  const PrivacyConsentRecord({
    required this.collectionUseVersion,
    required this.hospitalProvisionVersion,
    required this.acceptedAt,
  });

  final String collectionUseVersion;
  final String hospitalProvisionVersion;
  final DateTime acceptedAt;
}
