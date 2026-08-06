// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_response_dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InvitationValidationResponseDto _$InvitationValidationResponseDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('InvitationValidationResponseDto', json, ($checkedConvert) {
  final val = InvitationValidationResponseDto(
    organizationId: $checkedConvert('organizationId', (v) => v as String),
    organizationName: $checkedConvert('organizationName', (v) => v as String),
    role: $checkedConvert('role', (v) => v as String),
    expiresAt: $checkedConvert('expiresAt', (v) => DateTime.parse(v as String)),
    requiredConsents: $checkedConvert(
      'requiredConsents',
      (v) => (v as List<dynamic>)
          .map(
            (e) =>
                RequiredPrivacyConsentDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    ),
  );
  return val;
});

RequiredPrivacyConsentDto _$RequiredPrivacyConsentDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RequiredPrivacyConsentDto', json, ($checkedConvert) {
  final val = RequiredPrivacyConsentDto(
    type: $checkedConvert('type', (v) => v as String),
    policyVersion: $checkedConvert('policyVersion', (v) => v as String),
  );
  return val;
});

ParamedicSignupResponseDto _$ParamedicSignupResponseDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ParamedicSignupResponseDto', json, ($checkedConvert) {
  final val = ParamedicSignupResponseDto(
    accountId: $checkedConvert('accountId', (v) => v as String),
    organizationId: $checkedConvert('organizationId', (v) => v as String),
    organizationName: $checkedConvert('organizationName', (v) => v as String),
    role: $checkedConvert('role', (v) => v as String),
    hospitalId: $checkedConvert('hospitalId', (v) => v as String?),
    receivingStatus: $checkedConvert('receivingStatus', (v) => v as String?),
  );
  return val;
});

ParamedicProfileResponseDto _$ParamedicProfileResponseDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ParamedicProfileResponseDto', json, ($checkedConvert) {
  final val = ParamedicProfileResponseDto(
    accountId: $checkedConvert('accountId', (v) => v as String),
    loginId: $checkedConvert('loginId', (v) => v as String),
    displayName: $checkedConvert('displayName', (v) => v as String),
    organizationId: $checkedConvert('organizationId', (v) => v as String),
    organizationName: $checkedConvert('organizationName', (v) => v as String),
    role: $checkedConvert('role', (v) => v as String),
    callbackContact: $checkedConvert('callbackContact', (v) => v as String),
    privacyConsent: $checkedConvert(
      'privacyConsent',
      (v) => PrivacyConsentResponseDto.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

PrivacyConsentResponseDto _$PrivacyConsentResponseDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PrivacyConsentResponseDto', json, ($checkedConvert) {
  final val = PrivacyConsentResponseDto(
    collectionUsePolicyVersion: $checkedConvert(
      'collectionUsePolicyVersion',
      (v) => v as String,
    ),
    hospitalProvisionPolicyVersion: $checkedConvert(
      'hospitalProvisionPolicyVersion',
      (v) => v as String,
    ),
    consentedAt: $checkedConvert(
      'consentedAt',
      (v) => DateTime.parse(v as String),
    ),
    legacyCombined: $checkedConvert('legacyCombined', (v) => v as bool),
  );
  return val;
});
