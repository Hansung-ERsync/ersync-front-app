import '../../../../core/error/app_exception.dart';
import '../../../../core/network/auth_tokens.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/network/models/auth_token_response_dto.dart';
import '../../../../core/network/token_storage.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/invitation_info.dart';
import '../../domain/repositories/auth_repository.dart';
import '../apis/auth_api.dart';
import '../mappers/auth_dto_mapper.dart';
import '../models/auth_request_dtos.dart';
import '../models/auth_response_dtos.dart';

class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this._api, this._tokenStorage);

  final AuthApi _api;
  final TokenStorage _tokenStorage;

  @override
  Future<InvitationInfo> validateInvitationCode(String code) {
    final String preservedCode = code.trim();
    return DioExceptionMapper.guard(() async {
      final InvitationValidationResponseDto response = await _api
          .validateInvitation(
            ValidateInvitationRequestDto(invitationCode: preservedCode),
          );
      if (response.role != 'PARAMEDIC') {
        throw const AppException('구급대원용 가입 코드가 아닙니다.', code: 'COMMON_001');
      }
      return response.toEntity(invitationCode: preservedCode);
    });
  }

  @override
  Future<void> signUp({
    required InvitationInfo invitation,
    required String displayName,
    required String username,
    required String password,
    required String callbackContact,
    required bool collectionUseConsent,
    required bool hospitalProvisionConsent,
  }) async {
    final String? collectionUseVersion = invitation.consentVersion(
      PrivacyConsentType.contactCollectionUse,
    );
    final String? hospitalProvisionVersion = invitation.consentVersion(
      PrivacyConsentType.hospitalProvision,
    );
    if (collectionUseVersion == null || hospitalProvisionVersion == null) {
      throw const AppException(
        '가입에 필요한 개인정보 동의 버전을 확인할 수 없습니다.',
        code: 'INVALID_RESPONSE',
      );
    }

    await DioExceptionMapper.guard(
      () => _api.signUpParamedic(
        ParamedicSignupRequestDto(
          invitationCode: invitation.code,
          displayName: displayName.trim(),
          loginId: username.trim(),
          password: password,
          contact: callbackContact.trim(),
          collectionUseConsentAccepted: collectionUseConsent,
          collectionUseConsentVersion: collectionUseVersion,
          hospitalProvisionConsentAccepted: hospitalProvisionConsent,
          hospitalProvisionConsentVersion: hospitalProvisionVersion,
        ),
      ),
    );
  }

  @override
  Future<AuthUser> signIn({
    required String username,
    required String password,
  }) async {
    final AuthTokenResponseDto response = await DioExceptionMapper.guard(
      () => _api.login(
        LoginRequestDto(loginId: username.trim(), password: password),
      ),
    );
    final AuthTokens tokens = response.toTokens();
    if (tokens.role != 'PARAMEDIC') {
      throw const AppException(
        '구급대원 계정으로 로그인해주세요.',
        code: 'AUTH_003',
        statusCode: 403,
      );
    }
    await _tokenStorage.write(tokens);
    try {
      return await _getMyProfile();
    } on AppException catch (error) {
      if (_shouldClearSession(error)) {
        await _tokenStorage.clear();
      }
      rethrow;
    }
  }

  @override
  Future<AuthUser?> restoreSession() async {
    if (await _tokenStorage.read() == null) {
      return null;
    }
    try {
      return await _getMyProfile();
    } on AppException catch (error) {
      if (_shouldClearSession(error)) {
        await _tokenStorage.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() => _tokenStorage.clear();

  Future<AuthUser> _getMyProfile() {
    return DioExceptionMapper.guard(() async {
      final ParamedicProfileResponseDto response = await _api.getMyProfile();
      return response.toEntity();
    });
  }

  bool _shouldClearSession(AppException error) {
    return error.statusCode == 401 ||
        error.statusCode == 403 ||
        const <String>{
          'AUTH_001',
          'AUTH_002',
          'AUTH_003',
          'AUTH_005',
          'COMMON_004',
          'USER_002',
        }.contains(error.code);
  }
}
