import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this.repository);
  final AuthRepository repository;
  bool busy = false;
  bool succeeded = false;
  bool failed = false;
  String? errorCode;
  DateTime? resendAvailableAt;

  Future<void> resend(String email) async {
    if (busy || (resendAvailableAt?.isAfter(DateTime.now()) ?? false)) return;
    resendAvailableAt = DateTime.now().add(const Duration(seconds: 60));
    await submit('resend', email, '', '');
  }

  bool _disposed = false;

  Future<void> submit(
    String mode,
    String email,
    String password,
    String name,
  ) async {
    if (busy) return;
    busy = true;
    failed = false;
    succeeded = false;
    errorCode = null;
    notifyListeners();
    try {
      switch (mode) {
        case 'resend':
          await repository.resendVerification(email);
        case 'register':
          await repository.register(email, password, name);
        case 'forgotPassword':
          await repository.resetPassword(email);
        case 'resetPassword':
          await repository.updatePassword(password);
        default:
          await repository.login(email, password);
      }
      succeeded = true;
    } on AuthException catch (error) {
      failed = true;
      errorCode = error.code;
    } on Object {
      failed = true;
      errorCode = 'network';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
