import '../entities/invitation_info.dart';
import '../repositories/auth_repository.dart';

class ValidateInvitationCode {
  const ValidateInvitationCode(this._repository);

  final AuthRepository _repository;

  Future<InvitationInfo> call(String code) {
    return _repository.validateInvitationCode(code);
  }
}
