import '../entities/auth_user.dart';
import '../entities/invitation_info.dart';

abstract interface class AuthRepository {
  Future<InvitationInfo> validateInvitationCode(String code);

  Future<void> signUp({
    required InvitationInfo invitation,
    required String displayName,
    required String username,
    required String password,
    required String callbackContact,
    required bool collectionUseConsent,
    required bool hospitalProvisionConsent,
  });

  Future<AuthUser> signIn({required String username, required String password});
}
