import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ChatCache {
  Future<Map<String, dynamic>?> read(
    String user,
    String household,
    String kind,
  );
  Future<void> write(
    String user,
    String household,
    String kind,
    Map<String, dynamic> data,
  );
  Future<void> clearHousehold(String user, String household);
  Future<void> clearUser(String user);
}

class SecureChatCache implements ChatCache {
  SecureChatCache(this.vault);
  final FlutterSecureStorage vault;
  Future<void> tail = Future.value();
  String key(String u, String h, String kind) => 'homecircle.chat.$u.$h.$kind';
  String registry(String u) => 'homecircle.chat.$u.keys';
  Future<T> serial<T>(Future<T> Function() action) {
    final result = tail.then((_) => action());
    tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<List<String>> keys(String user) async =>
      ((jsonDecode(await vault.read(key: registry(user)) ?? '[]')) as List)
          .cast<String>();
  @override
  Future<Map<String, dynamic>?> read(String u, String h, String kind) =>
      serial(() async {
        final text = await vault.read(key: key(u, h, kind));
        return text == null ? null : jsonDecode(text) as Map<String, dynamic>;
      });
  @override
  Future<void> write(
    String u,
    String h,
    String kind,
    Map<String, dynamic> data,
  ) => serial(() async {
    final name = key(u, h, kind), index = await keys(u);
    // Register first so logout can clear an interrupted write.
    if (!index.contains(name)) {
      await vault.write(key: registry(u), value: jsonEncode([...index, name]));
    }
    await vault.write(key: name, value: jsonEncode(data));
  });
  @override
  Future<void> clearHousehold(String u, String h) => serial(() async {
    final index = await keys(u), prefix = 'homecircle.chat.$u.$h.';
    for (final name in index.where((k) => k.startsWith(prefix))) {
      await vault.delete(key: name);
    }
    await vault.write(
      key: registry(u),
      value: jsonEncode(index.where((k) => !k.startsWith(prefix)).toList()),
    );
  });
  @override
  Future<void> clearUser(String u) => serial(() async {
    for (final name in await keys(u)) {
      await vault.delete(key: name);
    }
    await vault.delete(key: registry(u));
  });
}
