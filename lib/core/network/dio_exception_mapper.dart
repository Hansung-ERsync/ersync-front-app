import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';

import '../error/app_exception.dart';

class DioExceptionMapper {
  const DioExceptionMapper._();

  static Future<T> guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on AppException {
      rethrow;
    } on DioException catch (error) {
      throw fromDio(error);
    } on CheckedFromJsonException {
      throw _invalidResponse();
    } on FormatException {
      throw _invalidResponse();
    } on TypeError {
      throw _invalidResponse();
    }
  }

  static AppException fromDio(DioException error) {
    final Object? originalError = error.error;
    if (originalError is AppException) {
      return originalError;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const AppException(
          '서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.',
          code: 'NETWORK_TIMEOUT',
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const AppException(
          '서버에 연결할 수 없습니다. 네트워크 상태를 확인해주세요.',
          code: 'NETWORK_ERROR',
        );
      case DioExceptionType.cancel:
        return const AppException('요청이 취소되었습니다.', code: 'REQUEST_CANCELLED');
      case DioExceptionType.badResponse:
        return _fromResponse(error.response);
      case DioExceptionType.unknown:
        if (error.response != null) {
          return _fromResponse(error.response);
        }
        return const AppException(
          '서버에 연결할 수 없습니다. 네트워크 상태를 확인해주세요.',
          code: 'NETWORK_ERROR',
        );
    }
  }

  static AppException _fromResponse(Response<dynamic>? response) {
    final Map<String, dynamic>? error = _asJsonObject(response?.data);
    final Object? rawFieldErrors = error?['fieldErrors'];
    return AppException(
      error?['message'] is String
          ? error!['message']! as String
          : '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.',
      code: error?['code'] is String ? error!['code']! as String : null,
      statusCode: response?.statusCode,
      traceId: error?['traceId'] is String
          ? error!['traceId']! as String
          : null,
      fieldErrors: rawFieldErrors is List<dynamic>
          ? List<Object?>.unmodifiable(rawFieldErrors)
          : const <Object?>[],
    );
  }

  static Map<String, dynamic>? _asJsonObject(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map<dynamic, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static AppException _invalidResponse() {
    return const AppException('서버 응답을 처리할 수 없습니다.', code: 'INVALID_RESPONSE');
  }
}
