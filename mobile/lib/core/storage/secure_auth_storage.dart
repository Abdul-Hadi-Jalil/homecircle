import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase owns serialization and refresh; the platform vault stores its session.
class SecureAuthStorage extends LocalStorage {
  SecureAuthStorage(this.storage, this.namespace);
  final FlutterSecureStorage storage;
  final String namespace;
  String get _key => 'homecircle.$namespace.session';

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => await storage.containsKey(key: _key);
  @override
  Future<String?> accessToken() => storage.read(key: _key);
  @override
  Future<void> persistSession(String persistSessionString) =>
      storage.write(key: _key, value: persistSessionString);
  @override
  Future<void> removePersistedSession() => storage.delete(key: _key);
}

class SecurePkceStorage extends GotrueAsyncStorage {
  SecurePkceStorage(this.storage, this.namespace);
  final FlutterSecureStorage storage;
  final String namespace;
  String _key(String key) => 'homecircle.$namespace.pkce.$key';
  @override
  Future<String?> getItem({required String key}) =>
      storage.read(key: _key(key));
  @override
  Future<void> setItem({required String key, required String value}) =>
      storage.write(key: _key(key), value: value);
  @override
  Future<void> removeItem({required String key}) =>
      storage.delete(key: _key(key));
}
