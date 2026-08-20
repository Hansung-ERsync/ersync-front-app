import 'package:json_annotation/json_annotation.dart';

part 'auth_request_dtos.g.dart';

@JsonSerializable(createFactory: false)
class ValidateInvitationRequestDto {
  const ValidateInvitationRequestDto({required this.invitationCode});

  final String invitationCode;

  Map<String, dynamic> toJson() => _$ValidateInvitationRequestDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class ParamedicSignupRequestDto {
  const ParamedicSignupRequestDto({
    required this.invitationCode,
    required this.displayName,
    required this.loginId,
    required this.password,
    required this.contact,
    required this.collectionUseConsentAccepted,
    required this.collectionUseConsentVersion,
    required this.hospitalProvisionConsentAccepted,
    required this.hospitalProvisionConsentVersion,
  });

  final String invitationCode;
  final String displayName;
  final String loginId;
  final String password;
  final String contact;
  final bool collectionUseConsentAccepted;
  final String collectionUseConsentVersion;
  final bool hospitalProvisionConsentAccepted;
  final String hospitalProvisionConsentVersion;

  Map<String, dynamic> toJson() => _$ParamedicSignupRequestDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class LoginRequestDto {
  const LoginRequestDto({
    required this.loginId,
    required this.password,
    this.role = 'PARAMEDIC',
  });

  final String loginId;
  final String password;
  final String role;

  Map<String, dynamic> toJson() => _$LoginRequestDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class ParamedicProfileUpdateRequestDto {
  const ParamedicProfileUpdateRequestDto({
    required this.displayName,
    required this.callbackContact,
  });

  final String displayName;
  final String callbackContact;

  Map<String, dynamic> toJson() =>
      _$ParamedicProfileUpdateRequestDtoToJson(this);
}
