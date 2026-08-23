import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../../../../core/network/authenticated_request.dart';
import '../../../../core/network/models/auth_token_response_dto.dart';
import '../models/auth_request_dtos.dart';
import '../models/auth_response_dtos.dart';

part 'auth_api.g.dart';

@RestApi()
abstract class AuthApi {
  factory AuthApi(Dio dio, {String? baseUrl}) = _AuthApi;

  @POST('/api/v1/auth/invitations/validate')
  Future<InvitationValidationResponseDto> validateInvitation(
    @Body() ValidateInvitationRequestDto request,
  );

  @POST('/api/v1/auth/signups/paramedic')
  Future<void> signUpParamedic(@Body() ParamedicSignupRequestDto request);

  @POST('/api/v1/auth/login')
  Future<AuthTokenResponseDto> login(@Body() LoginRequestDto request);

  @AuthenticatedRequest()
  @GET('/api/v1/paramedics/me')
  Future<ParamedicProfileResponseDto> getMyProfile();

  @AuthenticatedRequest()
  @PUT('/api/v1/paramedics/me')
  Future<ParamedicProfileResponseDto> updateMyProfile(
    @Body() ParamedicProfileUpdateRequestDto request,
  );
}
