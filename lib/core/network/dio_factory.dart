import 'package:dio/dio.dart';

import 'api_config.dart';

class DioFactory {
  const DioFactory._();

  static Dio create({Uri? baseUri}) {
    return Dio(
      BaseOptions(
        baseUrl: (baseUri ?? ApiConfig.baseUri).toString(),
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: const <String, Object>{
          Headers.acceptHeader: Headers.jsonContentType,
        },
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        receiveDataWhenStatusError: true,
      ),
    );
  }
}
