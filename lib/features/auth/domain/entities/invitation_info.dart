enum UserRole {
  paramedic;

  static UserRole fromApiValue(String value) {
    return switch (value) {
      'PARAMEDIC' => UserRole.paramedic,
      _ => throw FormatException('지원하지 않는 사용자 역할입니다: $value'),
    };
  }

  String get apiValue {
    return switch (this) {
      UserRole.paramedic => 'PARAMEDIC',
    };
  }

  String get label {
    switch (this) {
      case UserRole.paramedic:
        return '구급대원';
    }
  }
}

enum PrivacyConsentType {
  contactCollectionUse('CONTACT_COLLECTION_USE'),
  hospitalProvision('HOSPITAL_PROVISION');

  const PrivacyConsentType(this.apiValue);

  final String apiValue;

  static PrivacyConsentType fromApiValue(String value) {
    return PrivacyConsentType.values.firstWhere(
      (PrivacyConsentType type) => type.apiValue == value,
      orElse: () => throw FormatException('지원하지 않는 동의 유형입니다: $value'),
    );
  }
}

class RequiredPrivacyConsent {
  const RequiredPrivacyConsent({
    required this.type,
    required this.policyVersion,
  });

  final PrivacyConsentType type;
  final String policyVersion;
}

class InvitationInfo {
  const InvitationInfo({
    required this.code,
    required this.organizationName,
    required this.role,
    this.organizationId = '',
    this.expiresAt,
    this.requiredConsents = const <RequiredPrivacyConsent>[],
  });

  final String code;
  final String organizationId;
  final String organizationName;
  final UserRole role;
  final DateTime? expiresAt;
  final List<RequiredPrivacyConsent> requiredConsents;

  String? consentVersion(PrivacyConsentType type) {
    for (final RequiredPrivacyConsent consent in requiredConsents) {
      if (consent.type == type) {
        return consent.policyVersion;
      }
    }
    return null;
  }
}
