import 'package:json_annotation/json_annotation.dart';

import '../auth_tokens.dart';

part 'auth_token_response_dto.g.dart';

@JsonSerializable(checked: true, createToJson: false)
class AuthTokenResponseDto {
  const AuthTokenResponseDto({
    required this.tokenType,
    required this.accessToken,
    required this.refreshToken,
    required this.role,
  });

  factory AuthTokenResponseDto.fromJson(Map<String, dynamic> json) =>
      _$AuthTokenResponseDtoFromJson(json);

  final String tokenType;
  final String accessToken;
  final String refreshToken;
  final String role;

  AuthTokens toTokens() {
    return AuthTokens(
      tokenType: tokenType,
      accessToken: accessToken,
      refreshToken: refreshToken,
      role: role,
    );
  }
}
