import '../../domain/entities/auth_user.dart';
import '../../domain/entities/invitation_info.dart';
import '../../domain/entities/privacy_consent_record.dart';
import '../models/auth_response_dtos.dart';

extension InvitationValidationResponseDtoMapper
    on InvitationValidationResponseDto {
  InvitationInfo toEntity({required String invitationCode}) {
    return InvitationInfo(
      code: invitationCode,
      organizationId: organizationId,
      organizationName: organizationName,
      role: UserRole.fromApiValue(role),
      expiresAt: expiresAt,
      requiredConsents: List<RequiredPrivacyConsent>.unmodifiable(
        requiredConsents.map(
          (RequiredPrivacyConsentDto consent) => RequiredPrivacyConsent(
            type: PrivacyConsentType.fromApiValue(consent.type),
            policyVersion: consent.policyVersion,
          ),
        ),
      ),
    );
  }
}

extension ParamedicProfileResponseDtoMapper on ParamedicProfileResponseDto {
  AuthUser toEntity() {
    return AuthUser(
      accountId: accountId,
      username: loginId,
      displayName: displayName,
      organizationId: organizationId,
      organizationName: organizationName,
      role: UserRole.fromApiValue(role),
      callbackContact: callbackContact,
      consentRecord: PrivacyConsentRecord(
        collectionUseVersion: privacyConsent.collectionUsePolicyVersion,
        hospitalProvisionVersion: privacyConsent.hospitalProvisionPolicyVersion,
        acceptedAt: privacyConsent.consentedAt,
        legacyCombined: privacyConsent.legacyCombined,
      ),
    );
  }
}
