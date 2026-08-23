import 'package:json_annotation/json_annotation.dart';

part 'auth_response_dtos.g.dart';

@JsonSerializable(checked: true, createToJson: false)
class InvitationValidationResponseDto {
  const InvitationValidationResponseDto({
    required this.organizationName,
    required this.role,
    required this.requiredConsents,
  });

  factory InvitationValidationResponseDto.fromJson(Map<String, dynamic> json) =>
      _$InvitationValidationResponseDtoFromJson(json);

  final String organizationName;
  final String role;
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
class ParamedicProfileResponseDto {
  const ParamedicProfileResponseDto({
    required this.accountId,
    required this.loginId,
    required this.displayName,
    required this.organizationName,
    required this.callbackContact,
  });

  factory ParamedicProfileResponseDto.fromJson(Map<String, dynamic> json) =>
      _$ParamedicProfileResponseDtoFromJson(json);

  final String accountId;
  final String loginId;
  final String displayName;
  final String organizationName;
  final String callbackContact;
}
