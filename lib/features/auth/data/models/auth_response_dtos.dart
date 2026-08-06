import 'package:json_annotation/json_annotation.dart';

part 'auth_response_dtos.g.dart';

@JsonSerializable(checked: true, createToJson: false)
class InvitationValidationResponseDto {
  const InvitationValidationResponseDto({
    required this.organizationId,
    required this.organizationName,
    required this.role,
    required this.expiresAt,
    required this.requiredConsents,
  });

  factory InvitationValidationResponseDto.fromJson(Map<String, dynamic> json) =>
      _$InvitationValidationResponseDtoFromJson(json);

  final String organizationId;
  final String organizationName;
  final String role;
  final DateTime expiresAt;
  final List<RequiredPrivacyConsentDto> requiredConsents;
}

@JsonSerializable(checked: true, createToJson: false)
class RequiredPrivacyConsentDto {
  const RequiredPrivacyConsentDto({
    required this.type,
    required this.policyVersion,
  });

  factory RequiredPrivacyConsentDto.fromJson(Map<String, dynamic> json) =>
      _$RequiredPrivacyConsentDtoFromJson(json);

  final String type;
  final String policyVersion;
}

@JsonSerializable(checked: true, createToJson: false)
class ParamedicSignupResponseDto {
  const ParamedicSignupResponseDto({
    required this.accountId,
    required this.organizationId,
    required this.organizationName,
    required this.role,
    this.hospitalId,
    this.receivingStatus,
  });

  factory ParamedicSignupResponseDto.fromJson(Map<String, dynamic> json) =>
      _$ParamedicSignupResponseDtoFromJson(json);

  final String accountId;
  final String organizationId;
  final String organizationName;
  final String role;
  final String? hospitalId;
  final String? receivingStatus;
}

@JsonSerializable(checked: true, createToJson: false)
class ParamedicProfileResponseDto {
  const ParamedicProfileResponseDto({
    required this.accountId,
    required this.loginId,
    required this.displayName,
    required this.organizationId,
    required this.organizationName,
    required this.role,
    required this.callbackContact,
    required this.privacyConsent,
  });

  factory ParamedicProfileResponseDto.fromJson(Map<String, dynamic> json) =>
      _$ParamedicProfileResponseDtoFromJson(json);

  final String accountId;
  final String loginId;
  final String displayName;
  final String organizationId;
  final String organizationName;
  final String role;
  final String callbackContact;
  final PrivacyConsentResponseDto privacyConsent;
}

@JsonSerializable(checked: true, createToJson: false)
class PrivacyConsentResponseDto {
  const PrivacyConsentResponseDto({
    required this.collectionUsePolicyVersion,
    required this.hospitalProvisionPolicyVersion,
    required this.consentedAt,
    required this.legacyCombined,
  });

  factory PrivacyConsentResponseDto.fromJson(Map<String, dynamic> json) =>
      _$PrivacyConsentResponseDtoFromJson(json);

  final String collectionUsePolicyVersion;
  final String hospitalProvisionPolicyVersion;
  final DateTime consentedAt;
  final bool legacyCombined;
}
