import '../models/auth_identity.dart';
import '../services/auth_service.dart';

class AuthRepository {
  AuthRepository(this.service);
  final AuthService service;
  Stream<AuthIdentity?> get changes => service.changes;
  Future<AuthIdentity?> restore() => service.restore();
  Future<void> login(String email, String password) =>
      service.login(email.trim(), password);
  Future<void> register(String email, String password, String displayName) =>
      service.register(email.trim(), password, displayName.trim());
  Future<void> resetPassword(String email) =>
      service.sendPasswordReset(email.trim());
  Future<void> updatePassword(String password) =>
      service.updatePassword(password);
  Future<void> logout() => service.logout();
  Future<void> resendVerification(String email) =>
      service.resendVerification(email.trim());
}
