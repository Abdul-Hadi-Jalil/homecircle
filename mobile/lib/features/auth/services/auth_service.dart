import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../models/auth_identity.dart';

abstract interface class AuthService {
  Stream<AuthIdentity?> get changes;
  Future<AuthIdentity?> restore();
  Future<String?> accessToken();
  Future<void> login(String email, String password);
  Future<void> register(String email, String password, String displayName);
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<void> logout();
  Future<void> resendVerification(String email);
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this.client);
  final SupabaseClient client;

  AuthIdentity? _identity(User? user, {bool recovery = false}) => user == null
      ? null
      : AuthIdentity(
          id: user.id,
          email: user.email,
          passwordRecovery: recovery,
        );

  @override
  Stream<AuthIdentity?> get changes => client.auth.onAuthStateChange.map(
    (state) => _identity(
      state.session?.user,
      recovery: state.event == AuthChangeEvent.passwordRecovery,
    ),
  );

  @override
  Future<AuthIdentity?> restore() async {
    final session = client.auth.currentSession;
    if (session != null && session.isExpired) {
      await client.auth.refreshSession();
    }
    return _identity(client.auth.currentUser);
  }

  @override
  Future<String?> accessToken() async {
    try {
      final session = client.auth.currentSession;
      if (session == null) return null;
      if (session.isExpired) await client.auth.refreshSession();
      return client.auth.currentSession?.accessToken;
    } on AuthRetryableFetchException {
      throw const NetworkException();
    } on AuthException {
      throw const UnauthorizedException();
    }
  }

  @override
  Future<void> login(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {
    await client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
      emailRedirectTo: AppConfig.authCallback,
    );
  }

  @override
  Future<void> sendPasswordReset(String email) => client.auth
      .resetPasswordForEmail(email, redirectTo: AppConfig.authCallback);
  @override
  Future<void> updatePassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<void> logout() => client.auth.signOut(scope: SignOutScope.local);

  @override
  Future<void> resendVerification(String email) async {
    await client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: AppConfig.authCallback,
    );
  }
}
