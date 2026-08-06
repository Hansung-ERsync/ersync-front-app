class AuthTokens {
  const AuthTokens({
    required this.tokenType,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    required this.accountId,
    required this.organizationId,
    required this.role,
  });

  final String tokenType;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
  final String accountId;
  final String organizationId;
  final String role;

  factory AuthTokens.fromApiJson(Map<String, Object?> json) {
    return AuthTokens(
      tokenType: _requiredString(json, 'tokenType'),
      accessToken: _requiredString(json, 'accessToken'),
      accessTokenExpiresAt: DateTime.parse(
        _requiredString(json, 'accessTokenExpiresAt'),
      ),
      refreshToken: _requiredString(json, 'refreshToken'),
      refreshTokenExpiresAt: DateTime.parse(
        _requiredString(json, 'refreshTokenExpiresAt'),
      ),
      accountId: _requiredString(json, 'accountId'),
      organizationId: _requiredString(json, 'organizationId'),
      role: _requiredString(json, 'role'),
    );
  }

  factory AuthTokens.fromStorageJson(Map<String, Object?> json) {
    return AuthTokens.fromApiJson(json);
  }

  Map<String, Object?> toStorageJson() {
    return <String, Object?>{
      'tokenType': tokenType,
      'accessToken': accessToken,
      'accessTokenExpiresAt': accessTokenExpiresAt.toUtc().toIso8601String(),
      'refreshToken': refreshToken,
      'refreshTokenExpiresAt': refreshTokenExpiresAt.toUtc().toIso8601String(),
      'accountId': accountId,
      'organizationId': organizationId,
      'role': role,
    };
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('필수 토큰 응답 필드가 없습니다: $key');
    }
    return value;
  }
}
