import '../../../../core/error/app_exception.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/invitation_info.dart';
import '../../domain/entities/privacy_consent_record.dart';

class MockAuthDataSource {
  MockAuthDataSource()
    : _invitations = <String, _MockInvitationRecord>{
        mockInvitationCode: _MockInvitationRecord(
          code: mockInvitationCode,
          organizationName: '강동소방서 3구급대',
          role: UserRole.paramedic,
        ),
      },
      _accounts = <String, _MockAccountRecord>{
        mockUsername: _MockAccountRecord(
          username: mockUsername,
          password: mockPassword,
          displayName: '김민준',
          organizationName: '강동소방서 3구급대',
          role: UserRole.paramedic,
          callbackContact: mockCallbackContact,
          consentRecord: PrivacyConsentRecord(
            collectionUseVersion: collectionUseConsentVersion,
            hospitalProvisionVersion: hospitalProvisionConsentVersion,
            acceptedAt: DateTime(2026, 8, 1, 9),
          ),
        ),
      };

  static const String mockInvitationCode = 'ERSYNC-EMS-001';
  static const String mockUsername = 'paramedic01';
  static const String mockPassword = 'test1234';
  static const String mockCallbackContact = '010-0000-0000';
  static const String collectionUseConsentVersion = 'COLLECTION_USE_DEV_1.0';
  static const String hospitalProvisionConsentVersion =
      'HOSPITAL_PROVISION_DEV_1.0';

  final Map<String, _MockInvitationRecord> _invitations;
  final Map<String, _MockAccountRecord> _accounts;

  Future<InvitationInfo> validateInvitationCode(String code) async {
    await _delay();

    final String normalizedCode = code.trim();
    final _MockInvitationRecord? invitation = _invitations[normalizedCode];

    if (invitation == null) {
      throw const AppException('유효하지 않은 가입 코드입니다.');
    }
    if (invitation.isUsed) {
      throw const AppException('이미 사용된 가입 코드입니다.');
    }

    return invitation.toEntity();
  }

  Future<void> signUp({
    required InvitationInfo invitation,
    required String displayName,
    required String username,
    required String password,
    required String callbackContact,
    required bool collectionUseConsent,
    required bool hospitalProvisionConsent,
  }) async {
    await _delay();

    final String normalizedUsername = username.trim();
    final _MockInvitationRecord? invitationRecord =
        _invitations[invitation.code];

    if (invitationRecord == null || invitationRecord.isUsed) {
      throw const AppException('가입 코드를 다시 확인해주세요.');
    }
    if (_accounts.containsKey(normalizedUsername)) {
      throw const AppException('이미 사용 중인 아이디입니다.');
    }
    final String normalizedContact = callbackContact.trim();
    if (!RegExp(r'^010-\d{4}-\d{4}$').hasMatch(normalizedContact)) {
      throw const AppException('회신 연락처 형식을 확인해주세요.');
    }
    if (!collectionUseConsent || !hospitalProvisionConsent) {
      throw const AppException('필수 개인정보 동의 항목을 확인해주세요.');
    }

    _accounts[normalizedUsername] = _MockAccountRecord(
      username: normalizedUsername,
      password: password,
      displayName: displayName.trim(),
      organizationName: invitation.organizationName,
      role: invitation.role,
      callbackContact: normalizedContact,
      consentRecord: PrivacyConsentRecord(
        collectionUseVersion: collectionUseConsentVersion,
        hospitalProvisionVersion: hospitalProvisionConsentVersion,
        acceptedAt: DateTime.now(),
      ),
    );
    invitationRecord.isUsed = true;
  }

  Future<AuthUser> signIn({
    required String username,
    required String password,
  }) async {
    await _delay();

    final _MockAccountRecord? account = _accounts[username.trim()];
    if (account == null || account.password != password) {
      throw const AppException('아이디 또는 비밀번호를 확인해주세요.');
    }

    return account.toEntity();
  }

  Future<void> _delay() {
    return Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

class _MockInvitationRecord {
  _MockInvitationRecord({
    required this.code,
    required this.organizationName,
    required this.role,
  });

  final String code;
  final String organizationName;
  final UserRole role;
  bool isUsed = false;

  InvitationInfo toEntity() {
    return InvitationInfo(
      code: code,
      organizationName: organizationName,
      role: role,
    );
  }
}

class _MockAccountRecord {
  const _MockAccountRecord({
    required this.username,
    required this.password,
    required this.displayName,
    required this.organizationName,
    required this.role,
    required this.callbackContact,
    required this.consentRecord,
  });

  final String username;
  final String password;
  final String displayName;
  final String organizationName;
  final UserRole role;
  final String callbackContact;
  final PrivacyConsentRecord consentRecord;

  AuthUser toEntity() {
    return AuthUser(
      username: username,
      displayName: displayName,
      organizationName: organizationName,
      role: role,
      callbackContact: callbackContact,
      consentRecord: consentRecord,
    );
  }
}
