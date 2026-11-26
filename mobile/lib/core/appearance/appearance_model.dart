import 'package:flutter/foundation.dart';

import '../storage/local_store.dart';

/// Device-level display preferences (kept locally, never sent to the server).
class AppearanceModel extends ChangeNotifier {
  AppearanceModel(this._store)
    : _highContrast = _store.preferences.getBool(_key) ?? false;
  static const _key = 'appearance_high_contrast';
  final LocalStore _store;
  bool _highContrast;

  /// Bold, higher-contrast text rendering for readability.
  bool get highContrast => _highContrast;

  Future<void> setHighContrast(bool value) async {
    if (value == _highContrast) return;
    _highContrast = value;
    notifyListeners();
    await _store.preferences.setBool(_key, value);
  }
}
