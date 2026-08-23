// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_request_dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$ValidateInvitationRequestDtoToJson(
  ValidateInvitationRequestDto instance,
) => <String, dynamic>{'invitationCode': instance.invitationCode};

Map<String, dynamic> _$ParamedicSignupRequestDtoToJson(
  ParamedicSignupRequestDto instance,
) => <String, dynamic>{
  'invitationCode': instance.invitationCode,
  'displayName': instance.displayName,
  'loginId': instance.loginId,
  'password': instance.password,
  'contact': instance.contact,
  'collectionUseConsentAccepted': instance.collectionUseConsentAccepted,
  'collectionUseConsentVersion': instance.collectionUseConsentVersion,
  'hospitalProvisionConsentAccepted': instance.hospitalProvisionConsentAccepted,
  'hospitalProvisionConsentVersion': instance.hospitalProvisionConsentVersion,
};

Map<String, dynamic> _$LoginRequestDtoToJson(LoginRequestDto instance) =>
    <String, dynamic>{
      'loginId': instance.loginId,
      'password': instance.password,
      'role': instance.role,
    };

Map<String, dynamic> _$ParamedicProfileUpdateRequestDtoToJson(
  ParamedicProfileUpdateRequestDto instance,
) => <String, dynamic>{
  'displayName': instance.displayName,
  'callbackContact': instance.callbackContact,
};
