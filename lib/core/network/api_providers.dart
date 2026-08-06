import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'apis/token_api.dart';
import 'auth_token_interceptor.dart';
import 'dio_factory.dart';
import 'token_storage.dart';

final Provider<TokenStorage> tokenStorageProvider = Provider<TokenStorage>(
  (Ref ref) => const SecureTokenStorage(),
);

final Provider<Dio> tokenDioProvider = Provider<Dio>((Ref ref) {
  final Dio dio = DioFactory.create();
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

final Provider<TokenApi> tokenApiProvider = Provider<TokenApi>(
  (Ref ref) => TokenApi(ref.watch(tokenDioProvider)),
);

final Provider<Dio> dioProvider = Provider<Dio>((Ref ref) {
  final Dio dio = DioFactory.create();
  dio.interceptors.add(
    AuthTokenInterceptor(
      dio: dio,
      tokenApi: ref.watch(tokenApiProvider),
      tokenStorage: ref.watch(tokenStorageProvider),
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});
