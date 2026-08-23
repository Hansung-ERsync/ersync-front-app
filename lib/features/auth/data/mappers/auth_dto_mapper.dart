import '../../domain/entities/auth_user.dart';
import '../../domain/entities/invitation_info.dart';
import '../models/auth_response_dtos.dart';

extension InvitationValidationResponseDtoMapper
    on InvitationValidationResponseDto {
  InvitationInfo toEntity({required String invitationCode}) {
    return InvitationInfo(
      code: invitationCode,
      organizationName: organizationName,
      role: UserRole.fromApiValue(role),
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
      organizationName: organizationName,
      callbackContact: callbackContact,
    );
  }
}
