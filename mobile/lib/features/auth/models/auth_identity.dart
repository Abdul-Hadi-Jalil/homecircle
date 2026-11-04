class AuthIdentity {
  const AuthIdentity({
    required this.id,
    this.email,
    this.passwordRecovery = false,
  });
  final String id;
  final String? email;
  final bool passwordRecovery;
}
