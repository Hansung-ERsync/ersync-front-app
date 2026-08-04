import '../../domain/entities/auth_user.dart';
import '../../domain/entities/invitation_info.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/mock_auth_data_source.dart';

class MockAuthRepository implements AuthRepository {
  const MockAuthRepository(this._dataSource);

  final MockAuthDataSource _dataSource;

  @override
  Future<AuthUser> signIn({
    required String username,
    required String password,
  }) {
    return _dataSource.signIn(username: username, password: password);
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
  }) {
    return _dataSource.signUp(
      invitation: invitation,
      displayName: displayName,
      username: username,
      password: password,
      callbackContact: callbackContact,
      collectionUseConsent: collectionUseConsent,
      hospitalProvisionConsent: hospitalProvisionConsent,
    );
  }

  @override
  Future<InvitationInfo> validateInvitationCode(String code) {
    return _dataSource.validateInvitationCode(code);
  }
}
