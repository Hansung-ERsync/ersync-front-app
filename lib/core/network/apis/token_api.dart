import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/auth_token_response_dto.dart';
import '../models/refresh_token_request_dto.dart';

part 'token_api.g.dart';

@RestApi()
abstract class TokenApi {
  factory TokenApi(Dio dio, {String? baseUrl}) = _TokenApi;

  @POST('/api/v1/auth/tokens/refresh')
  Future<AuthTokenResponseDto> refreshToken(
    @Body() RefreshTokenRequestDto request,
  );
}
