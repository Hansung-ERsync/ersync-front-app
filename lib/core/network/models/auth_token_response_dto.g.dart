// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_token_response_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthTokenResponseDto _$AuthTokenResponseDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AuthTokenResponseDto', json, ($checkedConvert) {
  final val = AuthTokenResponseDto(
    tokenType: $checkedConvert('tokenType', (v) => v as String),
    accessToken: $checkedConvert('accessToken', (v) => v as String),
    refreshToken: $checkedConvert('refreshToken', (v) => v as String),
    role: $checkedConvert('role', (v) => v as String),
  );
  return val;
});
