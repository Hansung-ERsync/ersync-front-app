import 'package:json_annotation/json_annotation.dart';

import '../auth_tokens.dart';

part 'auth_token_response_dto.g.dart';

@JsonSerializable(checked: true, createToJson: false)
class AuthTokenResponseDto {
  const AuthTokenResponseDto({
    required this.tokenType,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    required this.accountId,
    required this.organizationId,
    required this.role,
  });

  factory AuthTokenResponseDto.fromJson(Map<String, dynamic> json) =>
      _$AuthTokenResponseDtoFromJson(json);

  final String tokenType;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
  final String accountId;
  final String organizationId;
  final String role;

  AuthTokens toTokens() {
    return AuthTokens(
      tokenType: tokenType,
      accessToken: accessToken,
      accessTokenExpiresAt: accessTokenExpiresAt,
      refreshToken: refreshToken,
      refreshTokenExpiresAt: refreshTokenExpiresAt,
      accountId: accountId,
      organizationId: organizationId,
      role: role,
    );
  }
}
