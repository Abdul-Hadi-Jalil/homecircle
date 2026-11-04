import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small, nonsensitive preferences/drafts only. Every private key is user-scoped.
class LocalStore {
  LocalStore(this.preferences);
  final SharedPreferences preferences;

  String _prefix(String userId) => 'homecircle.user.$userId.';
  String? activeHousehold(String userId) =>
      preferences.getString('${_prefix(userId)}active');

  Future<void> setActiveHousehold(String userId, String? householdId) async {
    final key = '${_prefix(userId)}active';
    if (householdId == null) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, householdId);
    }
  }

  Future<void> saveDraft(
    String userId,
    String householdId,
    String form,
    Map<String, dynamic> draft,
  ) async {
    await preferences.setString(
      '${_prefix(userId)}household.$householdId.draft.$form',
      jsonEncode(draft),
    );
  }

  Map<String, dynamic>? readDraft(
    String userId,
    String householdId,
    String form,
  ) => _readMap('${_prefix(userId)}household.$householdId.draft.$form');

  Future<void> cache(
    String userId,
    String householdId,
    String resource,
    Map<String, dynamic> data,
  ) async {
    await preferences.setString(
      '${_prefix(userId)}household.$householdId.cache.$resource',
      jsonEncode(data),
    );
  }

  Map<String, dynamic>? readCache(
    String userId,
    String householdId,
    String resource,
  ) => _readMap('${_prefix(userId)}household.$householdId.cache.$resource');

  Map<String, dynamic>? _readMap(String key) {
    try {
      final value = preferences.getString(key);
      return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }

  Future<void> clearHousehold(String userId, String householdId) =>
      _clearPrefix('${_prefix(userId)}household.$householdId.');
  Future<void> clearUser(String userId) => _clearPrefix(_prefix(userId));

  Future<void> retainHouseholds(String userId, Set<String> allowedIds) async {
    final prefix = '${_prefix(userId)}household.';
    for (final key
        in preferences
            .getKeys()
            .where((key) => key.startsWith(prefix))
            .toList()) {
      final householdId = key.substring(prefix.length).split('.').first;
      if (!allowedIds.contains(householdId)) await preferences.remove(key);
    }
  }

  Future<void> _clearPrefix(String prefix) async {
    for (final key
        in preferences
            .getKeys()
            .where((key) => key.startsWith(prefix))
            .toList()) {
      await preferences.remove(key);
    }
  }
}
