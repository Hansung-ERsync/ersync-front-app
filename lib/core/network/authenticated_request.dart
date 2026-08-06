import 'package:retrofit/dio.dart';

class AuthenticatedRequest extends TypedExtras {
  const AuthenticatedRequest({this.requiresAuth = true});

  final bool requiresAuth;
}

abstract final class NetworkRequestExtraKeys {
  static const String requiresAuth = 'requiresAuth';
  static const String accessTokenUsed = 'accessTokenUsed';
  static const String authRetried = 'authRetried';
}
