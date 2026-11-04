import 'package:flutter/foundation.dart';

import '../repositories/diagnostics_repository.dart';

class DiagnosticsViewModel extends ChangeNotifier {
  DiagnosticsViewModel(this.repository);
  final DiagnosticsRepository repository;
  bool busy = false;
  bool? success;
  bool profile = false;
  bool _disposed = false;
  int _generation = 0;

  void reset() {
    ++_generation;
    busy = false;
    success = null;
    profile = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> check({bool authenticated = false}) async {
    if (busy) return;
    final generation = ++_generation;
    busy = true;
    success = null;
    profile = authenticated;
    notifyListeners();
    try {
      if (authenticated) {
        await repository.checkProfile();
      } else {
        await repository.checkHealth();
      }
      if (generation == _generation) success = true;
    } on Object {
      if (generation == _generation) success = false;
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
