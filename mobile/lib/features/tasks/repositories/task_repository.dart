import '../../../core/errors/app_exception.dart';
import '../../../core/storage/local_store.dart';
import '../services/task_api_service.dart';

class TaskRead {
  TaskRead(this.data, {this.cached = false});
  final Map<String, dynamic> data;
  final bool cached;
}

class TaskRepository {
  TaskRepository(this.service, this.store);
  final TaskApiService service;
  final LocalStore store;
  Future<TaskRead> read(
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
      if (current()) await store.cache(user, household, 'tasks.$key', data);
      return TaskRead(data);
    } on NetworkException {
      if (!current()) rethrow;
      final data = store.readCache(user, household, 'tasks.$key');
      if (data == null) rethrow;
      return TaskRead(data, cached: true);
    } on ForbiddenException {
      if (current()) await store.clearHousehold(user, household);
      rethrow;
    } on UnauthorizedException {
      if (current()) await store.clearUser(user);
      rethrow;
    }
  }

  Future<void> invalidate(String user, String household) async {
    final prefix = 'homecircle.user.$user.household.$household.cache.tasks.';
    for (final key
        in store.preferences
            .getKeys()
            .where((key) => key.startsWith(prefix))
            .toList()) {
      await store.preferences.remove(key);
    }
  }
}
