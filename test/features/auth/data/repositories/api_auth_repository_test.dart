import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:er_sync/core/error/app_exception.dart';
import 'package:er_sync/core/network/apis/token_api.dart';
import 'package:er_sync/core/network/auth_token_interceptor.dart';
import 'package:er_sync/core/network/auth_tokens.dart';
import 'package:er_sync/core/network/dio_exception_mapper.dart';
import 'package:er_sync/core/network/dio_factory.dart';
import 'package:er_sync/core/network/token_storage.dart';
import 'package:er_sync/features/auth/data/apis/auth_api.dart';
import 'package:er_sync/features/auth/data/repositories/api_auth_repository.dart';
import 'package:er_sync/features/auth/domain/entities/invitation_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Uri baseUri = Uri.parse('http://localhost');

  test('가입 코드 원문과 서버 동의 버전을 회원가입 요청에 유지한다', () async {
    final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
    late Map<String, dynamic> signUpBody;
    final _MockHttpClientAdapter adapter = _MockHttpClientAdapter((
      RequestOptions request,
    ) async {
      if (request.uri.path == '/api/v1/auth/invitations/validate') {
        expect(_requestJson(request), <String, Object?>{
          'invitationCode': 'Case-Sensitive-Code',
        });
        return _jsonResponse(<String, Object?>{
          'organizationId': 'EMS-1',
          'organizationName': '한성구급대',
          'role': 'PARAMEDIC',
          'expiresAt': '2026-08-07T09:00:00Z',
          'requiredConsents': <Object?>[
            <String, Object?>{
              'type': 'CONTACT_COLLECTION_USE',
              'policyVersion': 'COLLECTION_USE_DEV_1.0',
            },
            <String, Object?>{
              'type': 'HOSPITAL_PROVISION',
              'policyVersion': 'HOSPITAL_PROVISION_DEV_1.0',
            },
          ],
        });
      }
      if (request.uri.path == '/api/v1/auth/signups/paramedic') {
        signUpBody = _requestJson(request);
        return _jsonResponse(<String, Object?>{
          'accountId': 'ACCOUNT-1',
          'organizationId': 'EMS-1',
          'organizationName': '한성구급대',
          'role': 'PARAMEDIC',
          'hospitalId': null,
          'receivingStatus': null,
        }, statusCode: 201);
      }
      fail('예상하지 못한 요청입니다: ${request.method} ${request.uri}');
    });
    final ApiAuthRepository repository = _repository(
      adapter,
      tokenStorage,
      baseUri,
    );

    final InvitationInfo invitation = await repository.validateInvitationCode(
      ' Case-Sensitive-Code ',
    );
    await repository.signUp(
      invitation: invitation,
      displayName: ' 김민준 ',
      username: 'paramedic01',
      password: 'safe-password',
      callbackContact: '010-0000-0000',
      collectionUseConsent: true,
      hospitalProvisionConsent: true,
    );

    expect(invitation.code, 'Case-Sensitive-Code');
    expect(invitation.organizationId, 'EMS-1');
    expect(
      invitation.consentVersion(PrivacyConsentType.contactCollectionUse),
      'COLLECTION_USE_DEV_1.0',
    );
    expect(signUpBody['invitationCode'], 'Case-Sensitive-Code');
    expect(signUpBody['displayName'], '김민준');
    expect(signUpBody['collectionUseConsentAccepted'], isTrue);
    expect(signUpBody['collectionUseConsentVersion'], 'COLLECTION_USE_DEV_1.0');
    expect(signUpBody['hospitalProvisionConsentAccepted'], isTrue);
    expect(
      signUpBody['hospitalProvisionConsentVersion'],
      'HOSPITAL_PROVISION_DEV_1.0',
    );
  });

  test('로그인 토큰을 저장한 뒤 Bearer 인증으로 내 프로필을 조회한다', () async {
    final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
    final _MockHttpClientAdapter adapter = _MockHttpClientAdapter((
      RequestOptions request,
    ) async {
      if (request.uri.path == '/api/v1/auth/login') {
        expect(request.headers['Authorization'], isNull);
        expect(_requestJson(request), <String, Object?>{
          'loginId': 'paramedic01',
          'password': 'safe-password',
          'role': 'PARAMEDIC',
        });
        return _jsonResponse(_tokenResponse('ACCESS-1', 'REFRESH-1'));
      }
      if (request.uri.path == '/api/v1/paramedics/me') {
        expect(request.headers['Authorization'], 'Bearer ACCESS-1');
        return _jsonResponse(_profileResponse());
      }
      fail('예상하지 못한 요청입니다: ${request.method} ${request.uri}');
    });
    final ApiAuthRepository repository = _repository(
      adapter,
      tokenStorage,
      baseUri,
    );

    final user = await repository.signIn(
      username: 'paramedic01',
      password: 'safe-password',
    );

    expect(user.accountId, 'ACCOUNT-1');
    expect(user.displayName, '김민준');
    expect(user.consentRecord.legacyCombined, isFalse);
    expect((await tokenStorage.read())?.refreshToken, 'REFRESH-1');
  });

  test('이름과 회신 연락처를 함께 수정하고 서버의 전체 프로필 응답을 사용한다', () async {
    final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
    await tokenStorage.write(
      AuthTokens.fromApiJson(_tokenResponse('ACCESS-1', 'REFRESH-1')),
    );
    final _MockHttpClientAdapter adapter = _MockHttpClientAdapter((
      RequestOptions request,
    ) async {
      expect(request.method, 'PUT');
      expect(request.uri.path, '/api/v1/paramedics/me');
      expect(request.headers['Authorization'], 'Bearer ACCESS-1');
      expect(request.contentType, Headers.jsonContentType);
      expect(request.headers['Idempotency-Key'], isNull);
      expect(_requestJson(request), <String, Object?>{
        'displayName': '새 이름',
        'callbackContact': '+82-10-1234-5678',
      });
      return _jsonResponse(
        _profileResponse(
          displayName: '서버 정규화 이름',
          callbackContact: '+82-10-1234-5678',
        ),
      );
    });
    final ApiAuthRepository repository = _repository(
      adapter,
      tokenStorage,
      baseUri,
    );

    final user = await repository.updateMyProfile(
      displayName: ' 새 이름 ',
      callbackContact: ' +82-10-1234-5678 ',
    );

    expect(user.displayName, '서버 정규화 이름');
    expect(user.callbackContact, '+82-10-1234-5678');
    expect(user.organizationName, '한성구급대');
    expect(user.consentRecord.collectionUseVersion, 'COLLECTION_USE_DEV_1.0');
  });

  test('연락처 동의 오류에서는 인증 정보를 유지하고 프로필 수정 실패를 전달한다', () async {
    final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
    await tokenStorage.write(
      AuthTokens.fromApiJson(_tokenResponse('ACCESS-1', 'REFRESH-1')),
    );
    final _MockHttpClientAdapter adapter = _MockHttpClientAdapter((
      RequestOptions request,
    ) async {
      return _jsonResponse(<String, Object?>{
        'code': 'USER_005',
        'message': '필요한 연락처 동의가 없습니다.',
        'fieldErrors': <Object?>[],
        'traceId': 'TRACE-CONSENT',
      }, statusCode: 409);
    });
    final ApiAuthRepository repository = _repository(
      adapter,
      tokenStorage,
      baseUri,
    );

    await expectLater(
      repository.updateMyProfile(
        displayName: '김민준',
        callbackContact: '010-1234-5678',
      ),
      throwsA(
        isA<AppException>()
            .having((AppException error) => error.code, 'code', 'USER_005')
            .having(
              (AppException error) => error.traceId,
              'traceId',
              'TRACE-CONSENT',
            ),
      ),
    );
    expect((await tokenStorage.read())?.accessToken, 'ACCESS-1');
  });

  test('프로필 연결 불일치 오류에서는 저장된 인증 정보를 제거한다', () async {
    final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
    await tokenStorage.write(
      AuthTokens.fromApiJson(_tokenResponse('ACCESS-1', 'REFRESH-1')),
    );
    final _MockHttpClientAdapter adapter = _MockHttpClientAdapter((
      RequestOptions request,
    ) async {
      return _jsonResponse(<String, Object?>{
        'code': 'COMMON_004',
        'message': '프로필 연결 정보가 일치하지 않습니다.',
        'fieldErrors': <Object?>[],
        'traceId': 'TRACE-LINK',
      }, statusCode: 403);
    });
    final ApiAuthRepository repository = _repository(
      adapter,
      tokenStorage,
      baseUri,
    );

    await expectLater(
      repository.updateMyProfile(
        displayName: '김민준',
        callbackContact: '010-1234-5678',
      ),
      throwsA(
        isA<AppException>().having(
          (AppException error) => error.code,
          'code',
          'COMMON_004',
        ),
      ),
    );
    expect(await tokenStorage.read(), isNull);
  });

  test('만료된 Access Token은 한 번 갱신하고 프로필 요청을 재시도한다', () async {
    final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
    await tokenStorage.write(
      AuthTokens.fromApiJson(_tokenResponse('OLD-ACCESS', 'OLD-REFRESH')),
    );
    int profileCallCount = 0;
    int refreshCallCount = 0;
    final _MockHttpClientAdapter adapter = _MockHttpClientAdapter((
      RequestOptions request,
    ) async {
      if (request.uri.path == '/api/v1/paramedics/me') {
        profileCallCount += 1;
        if (profileCallCount == 1) {
          expect(request.headers['Authorization'], 'Bearer OLD-ACCESS');
          return _jsonResponse(<String, Object?>{
            'code': 'AUTH_002',
            'message': '토큰이 만료되었습니다.',
            'fieldErrors': <Object?>[],
            'traceId': 'TRACE-1',
          }, statusCode: 401);
        }
        expect(request.headers['Authorization'], 'Bearer NEW-ACCESS');
        return _jsonResponse(_profileResponse());
      }
      if (request.uri.path == '/api/v1/auth/tokens/refresh') {
        refreshCallCount += 1;
        expect(request.headers['Authorization'], isNull);
        expect(_requestJson(request), <String, Object?>{
          'refreshToken': 'OLD-REFRESH',
        });
        return _jsonResponse(_tokenResponse('NEW-ACCESS', 'NEW-REFRESH'));
      }
      fail('예상하지 못한 요청입니다: ${request.method} ${request.uri}');
    });
    final ApiAuthRepository repository = _repository(
      adapter,
      tokenStorage,
      baseUri,
    );

    final user = await repository.restoreSession();

    expect(user?.username, 'paramedic01');
    expect(profileCallCount, 2);
    expect(refreshCallCount, 1);
    expect((await tokenStorage.read())?.accessToken, 'NEW-ACCESS');
    expect((await tokenStorage.read())?.refreshToken, 'NEW-REFRESH');
  });

  test('동시에 만료된 요청도 Refresh Token을 한 번만 회전한다', () async {
    final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
    await tokenStorage.write(
      AuthTokens.fromApiJson(_tokenResponse('OLD-ACCESS', 'OLD-REFRESH')),
    );
    int profileCallCount = 0;
    int refreshCallCount = 0;
    final _MockHttpClientAdapter adapter = _MockHttpClientAdapter((
      RequestOptions request,
    ) async {
      if (request.uri.path == '/api/v1/paramedics/me') {
        profileCallCount += 1;
        if (request.headers['Authorization'] == 'Bearer OLD-ACCESS') {
          return _jsonResponse(<String, Object?>{
            'code': 'AUTH_002',
            'message': '토큰이 만료되었습니다.',
            'fieldErrors': <Object?>[],
            'traceId': 'TRACE-$profileCallCount',
          }, statusCode: 401);
        }
        expect(request.headers['Authorization'], 'Bearer NEW-ACCESS');
        return _jsonResponse(_profileResponse());
      }
      if (request.uri.path == '/api/v1/auth/tokens/refresh') {
        refreshCallCount += 1;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _jsonResponse(_tokenResponse('NEW-ACCESS', 'NEW-REFRESH'));
      }
      fail('예상하지 못한 요청입니다: ${request.method} ${request.uri}');
    });
    final _ApiFixture fixture = _apiFixture(adapter, tokenStorage, baseUri);

    final List<dynamic> profiles = await Future.wait<dynamic>(<Future<dynamic>>[
      DioExceptionMapper.guard(fixture.authApi.getMyProfile),
      DioExceptionMapper.guard(fixture.authApi.getMyProfile),
    ]);

    expect(profiles, hasLength(2));
    expect(profileCallCount, 4);
    expect(refreshCallCount, 1);
    expect((await tokenStorage.read())?.refreshToken, 'NEW-REFRESH');
  });

  test('토큰 갱신이 거부되면 저장된 인증 정보를 제거한다', () async {
    final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
    await tokenStorage.write(
      AuthTokens.fromApiJson(_tokenResponse('OLD-ACCESS', 'OLD-REFRESH')),
    );
    final _MockHttpClientAdapter adapter = _MockHttpClientAdapter((
      RequestOptions request,
    ) async {
      if (request.uri.path == '/api/v1/paramedics/me') {
        return _jsonResponse(<String, Object?>{
          'code': 'AUTH_002',
          'message': '토큰이 만료되었습니다.',
          'fieldErrors': <Object?>[],
          'traceId': 'TRACE-1',
        }, statusCode: 401);
      }
      if (request.uri.path == '/api/v1/auth/tokens/refresh') {
        return _jsonResponse(<String, Object?>{
          'code': 'USER_002',
          'message': '비활성 계정입니다.',
          'fieldErrors': <Object?>[],
          'traceId': 'TRACE-2',
        }, statusCode: 403);
      }
      fail('예상하지 못한 요청입니다: ${request.method} ${request.uri}');
    });
    final _ApiFixture fixture = _apiFixture(adapter, tokenStorage, baseUri);

    await expectLater(
      DioExceptionMapper.guard(fixture.authApi.getMyProfile),
      throwsA(
        isA<AppException>()
            .having((AppException error) => error.code, 'code', 'USER_002')
            .having(
              (AppException error) => error.traceId,
              'traceId',
              'TRACE-2',
            ),
      ),
    );

    expect(await tokenStorage.read(), isNull);
  });
}

ApiAuthRepository _repository(
  HttpClientAdapter adapter,
  InMemoryTokenStorage tokenStorage,
  Uri baseUri,
) {
  final _ApiFixture fixture = _apiFixture(adapter, tokenStorage, baseUri);
  return ApiAuthRepository(fixture.authApi, tokenStorage);
}

_ApiFixture _apiFixture(
  HttpClientAdapter adapter,
  InMemoryTokenStorage tokenStorage,
  Uri baseUri,
) {
  final Dio tokenDio = DioFactory.create(baseUri: baseUri)
    ..httpClientAdapter = adapter;
  final TokenApi tokenApi = TokenApi(tokenDio);
  final Dio dio = DioFactory.create(baseUri: baseUri)
    ..httpClientAdapter = adapter;
  dio.interceptors.add(
    AuthTokenInterceptor(
      dio: dio,
      tokenApi: tokenApi,
      tokenStorage: tokenStorage,
    ),
  );
  return _ApiFixture(AuthApi(dio));
}

class _ApiFixture {
  const _ApiFixture(this.authApi);

  final AuthApi authApi;
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  _MockHttpClientAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions request) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _requestJson(RequestOptions request) {
  final Object? data = request.data;
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map<dynamic, dynamic>) {
    return Map<String, dynamic>.from(data);
  }
  if (data is String) {
    return Map<String, dynamic>.from(jsonDecode(data) as Map<dynamic, dynamic>);
  }
  fail('JSON 요청 본문이 아닙니다: $data');
}

ResponseBody _jsonResponse(Object body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

Map<String, dynamic> _tokenResponse(String accessToken, String refreshToken) {
  return <String, dynamic>{
    'tokenType': 'Bearer',
    'accessToken': accessToken,
    'accessTokenExpiresAt': '2026-08-05T09:15:00Z',
    'refreshToken': refreshToken,
    'refreshTokenExpiresAt': '2026-08-12T09:00:00Z',
    'accountId': 'ACCOUNT-1',
    'organizationId': 'EMS-1',
    'role': 'PARAMEDIC',
  };
}

Map<String, dynamic> _profileResponse({
  String displayName = '김민준',
  String callbackContact = '010-0000-0000',
}) {
  return <String, dynamic>{
    'accountId': 'ACCOUNT-1',
    'loginId': 'paramedic01',
    'displayName': displayName,
    'organizationId': 'EMS-1',
    'organizationName': '한성구급대',
    'role': 'PARAMEDIC',
    'callbackContact': callbackContact,
    'privacyConsent': <String, dynamic>{
      'collectionUsePolicyVersion': 'COLLECTION_USE_DEV_1.0',
      'hospitalProvisionPolicyVersion': 'HOSPITAL_PROVISION_DEV_1.0',
      'consentedAt': '2026-08-05T09:00:00Z',
      'legacyCombined': false,
    },
  };
}
