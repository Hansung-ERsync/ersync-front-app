import 'package:dio/dio.dart';

import '../error/app_exception.dart';
import 'apis/token_api.dart';
import 'authenticated_request.dart';
import 'auth_tokens.dart';
import 'dio_exception_mapper.dart';
import 'models/auth_token_response_dto.dart';
import 'models/refresh_token_request_dto.dart';
import 'token_storage.dart';

class AuthTokenInterceptor extends Interceptor {
  AuthTokenInterceptor({
    required Dio dio,
    required TokenApi tokenApi,
    required TokenStorage tokenStorage,
  }) : _dio = dio,
       _tokenApi = tokenApi,
       _tokenStorage = tokenStorage;

  final Dio _dio;
  final TokenApi _tokenApi;
  final TokenStorage _tokenStorage;

  Future<AuthTokens>? _refreshInFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[NetworkRequestExtraKeys.requiresAuth] != true) {
      handler.next(options);
      return;
    }

    try {
      final AuthTokens? tokens = await _tokenStorage.read();
      if (tokens == null) {
        handler.reject(
          _dioError(
            options,
            const AppException(
              '로그인이 필요합니다.',
              code: 'AUTH_001',
              statusCode: 401,
            ),
          ),
        );
        return;
      }
      options.headers['Authorization'] =
          '${tokens.tokenType} ${tokens.accessToken}';
      options.extra[NetworkRequestExtraKeys.accessTokenUsed] =
          tokens.accessToken;
      handler.next(options);
    } on AppException catch (error) {
      handler.reject(_dioError(options, error));
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRefresh(err)) {
      handler.next(err);
      return;
    }

    try {
      final AuthTokens tokens = await _refreshFor(err.requestOptions);
      final RequestOptions retryOptions = err.requestOptions.copyWith(
        headers: <String, dynamic>{
          ...err.requestOptions.headers,
          'Authorization': '${tokens.tokenType} ${tokens.accessToken}',
        },
        extra: <String, dynamic>{
          ...err.requestOptions.extra,
          NetworkRequestExtraKeys.authRetried: true,
          NetworkRequestExtraKeys.accessTokenUsed: tokens.accessToken,
        },
      );
      final Response<dynamic> response = await _dio.fetch<dynamic>(
        retryOptions,
      );
      handler.resolve(response);
    } on AppException catch (refreshError) {
      handler.reject(_dioError(err.requestOptions, refreshError));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _shouldRefresh(DioException error) {
    final Map<String, dynamic>? body = _asJsonObject(error.response?.data);
    return error.requestOptions.extra[NetworkRequestExtraKeys.requiresAuth] ==
            true &&
        error.requestOptions.extra[NetworkRequestExtraKeys.authRetried] !=
            true &&
        error.response?.statusCode == 401 &&
        body?['code'] == 'AUTH_002';
  }

  Future<AuthTokens> _refreshFor(RequestOptions failedRequest) async {
    final AuthTokens? current = await _tokenStorage.read();
    if (current == null) {
      throw const AppException(
        '로그인이 필요합니다.',
        code: 'AUTH_005',
        statusCode: 401,
      );
    }

    final Object? accessTokenUsed =
        failedRequest.extra[NetworkRequestExtraKeys.accessTokenUsed];
    if (accessTokenUsed is String && accessTokenUsed != current.accessToken) {
      return current;
    }
    return _refreshAccessToken();
  }

  Future<AuthTokens> _refreshAccessToken() async {
    final Future<AuthTokens>? pending = _refreshInFlight;
    if (pending != null) {
      return pending;
    }

    final Future<AuthTokens> refresh = _performRefresh();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<AuthTokens> _performRefresh() async {
    final AuthTokens? current = await _tokenStorage.read();
    if (current == null) {
      throw const AppException(
        '로그인이 필요합니다.',
        code: 'AUTH_005',
        statusCode: 401,
      );
    }

    try {
      final AuthTokenResponseDto response = await DioExceptionMapper.guard(
        () => _tokenApi.refreshToken(
          RefreshTokenRequestDto(refreshToken: current.refreshToken),
        ),
      );
      final AuthTokens refreshed = response.toTokens();
      await _tokenStorage.write(refreshed);
      return refreshed;
    } on AppException catch (error) {
      if (_mustClearSession(error)) {
        await _tokenStorage.clear();
      }
      rethrow;
    }
  }

  bool _mustClearSession(AppException error) {
    return error.statusCode == 401 ||
        error.statusCode == 403 ||
        error.code == 'AUTH_005' ||
        error.code == 'USER_002' ||
        error.code == 'INVALID_RESPONSE';
  }

  DioException _dioError(RequestOptions request, AppException error) {
    return DioException(
      requestOptions: request,
      response: error.statusCode == null
          ? null
          : Response<dynamic>(
              requestOptions: request,
              statusCode: error.statusCode,
              data: <String, Object?>{
                'code': error.code,
                'message': error.message,
                'fieldErrors': error.fieldErrors,
                'traceId': error.traceId,
              },
            ),
      type: DioExceptionType.unknown,
      error: error,
    );
  }

  Map<String, dynamic>? _asJsonObject(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map<dynamic, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }
}
