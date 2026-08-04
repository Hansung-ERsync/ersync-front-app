enum UserRole {
  paramedic;

  String get label {
    switch (this) {
      case UserRole.paramedic:
        return '구급대원';
    }
  }
}

class InvitationInfo {
  const InvitationInfo({
    required this.code,
    required this.organizationName,
    required this.role,
  });

  final String code;
  final String organizationName;
  final UserRole role;
}
