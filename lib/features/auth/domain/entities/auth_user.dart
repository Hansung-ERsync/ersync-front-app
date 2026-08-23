class AuthUser {
  const AuthUser({
    required this.accountId,
    required this.username,
    required this.displayName,
    required this.organizationName,
    required this.callbackContact,
  });

  final String accountId;
  final String username;
  final String displayName;
  final String organizationName;
  final String callbackContact;
}
