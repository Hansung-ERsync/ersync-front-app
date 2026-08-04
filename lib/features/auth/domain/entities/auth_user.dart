import 'invitation_info.dart';
import 'privacy_consent_record.dart';

class AuthUser {
  const AuthUser({
    required this.username,
    required this.displayName,
    required this.organizationName,
    required this.role,
    required this.callbackContact,
    required this.consentRecord,
  });

  final String username;
  final String displayName;
  final String organizationName;
  final UserRole role;
  final String callbackContact;
  final PrivacyConsentRecord consentRecord;
}
