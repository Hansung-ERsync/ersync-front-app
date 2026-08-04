import '../entities/invitation_info.dart';
import '../repositories/auth_repository.dart';

class SignUp {
  const SignUp(this._repository);

  final AuthRepository _repository;

  Future<void> call({
    required InvitationInfo invitation,
    required String displayName,
    required String username,
    required String password,
    required String callbackContact,
    required bool collectionUseConsent,
    required bool hospitalProvisionConsent,
  }) {
    return _repository.signUp(
      invitation: invitation,
      displayName: displayName,
      username: username,
      password: password,
      callbackContact: callbackContact,
      collectionUseConsent: collectionUseConsent,
      hospitalProvisionConsent: hospitalProvisionConsent,
    );
  }
}
