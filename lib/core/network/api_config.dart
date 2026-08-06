import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'ERSYNC_API_BASE_URL',
  );

  static Uri get baseUri {
    final String value = _configuredBaseUrl.isNotEmpty
        ? _configuredBaseUrl
        : 'http://13.124.194.249';
    final Uri uri = Uri.parse(value);
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw StateError('ERSYNC_API_BASE_URL이 올바른 URL이 아닙니다.');
    }
    if (kReleaseMode && uri.scheme != 'https') {
      throw StateError('릴리스 빌드의 ERSYNC_API_BASE_URL은 HTTPS여야 합니다.');
    }
    return uri;
  }
}
