class AuthTokens {
  const AuthTokens({
    required this.tokenType,
    required this.accessToken,
    required this.refreshToken,
    required this.role,
  });

  final String tokenType;
  final String accessToken;
  final String refreshToken;
  final String role;

  factory AuthTokens.fromApiJson(Map<String, Object?> json) {
    return AuthTokens(
      tokenType: _requiredString(json, 'tokenType'),
      accessToken: _requiredString(json, 'accessToken'),
      refreshToken: _requiredString(json, 'refreshToken'),
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
      'refreshToken': refreshToken,
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
