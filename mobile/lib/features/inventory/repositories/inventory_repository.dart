import '../../../core/errors/app_exception.dart';
import '../../../core/storage/local_store.dart';
import '../services/inventory_api.dart';

class InventoryRead<T> {
  InventoryRead(this.value, {this.cached = false});
  final T value;
  final bool cached;
}

class InventoryRepository {
  InventoryRepository(this.service, this.store);
  final InventoryApi service;
  final LocalStore store;

  Future<InventoryRead<Map<String, dynamic>>> read(
    String user,
    String household,
    String key,
    Future<Map<String, dynamic>> Function() fetch,
    bool Function() current,
  ) async {
    try {
      final data = await fetch();
      if (data['household_id'] != null && data['household_id'] != household) {
        throw const InvalidResponseException();
      }
      for (final row in (data['items'] as List? ?? [])) {
        if (row is Map &&
            row['household_id'] != null &&
            row['household_id'] != household) {
          throw const InvalidResponseException();
        }
      }
      if (current()) {
        await store.cache(user, household, 'inventory.$key', data);
        // List responses contain complete item fields, so an item visible in a
        // saved overview can be opened offline even if details were not visited.
        if (key.startsWith('list.')) {
          for (final row in (data['items'] as List? ?? [])) {
            if (!current()) break;
            final item = row as Map<String, dynamic>;
            await store.cache(
              user,
              household,
              'inventory.item.${item['id']}',
              item,
            );
          }
        }
      }
      return InventoryRead(data);
    } on NetworkException {
      if (!current()) rethrow;
      final data = store.readCache(user, household, 'inventory.$key');
      if (data == null) rethrow;
      return InventoryRead(data, cached: true);
    } on ForbiddenException {
      if (current()) await store.clearHousehold(user, household);
      rethrow;
    } on UnauthorizedException {
      if (current()) await store.clearUser(user);
      rethrow;
    }
  }

  Future<void> invalidate(String user, String household) async {
    final prefix =
        'homecircle.user.$user.household.$household.cache.inventory.';
    for (final key
        in store.preferences
            .getKeys()
            .where((key) => key.startsWith(prefix))
            .toList()) {
      await store.preferences.remove(key);
    }
  }
}
