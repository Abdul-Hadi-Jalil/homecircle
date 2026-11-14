import '../../../core/errors/app_exception.dart';
import '../../chat/repositories/chat_cache.dart';
import '../services/household_hub_api.dart';

class HubRead {
  HubRead(
    this.data,
    this.savedAt, {
    this.cached = false,
    this.cacheError = false,
  });
  final Map<String, dynamic> data;
  final DateTime savedAt;
  final bool cached, cacheError;
}

class HubRepository {
  HubRepository(this.service, this.cache);
  final HouseholdHubApi service;
  final ChatCache cache;
  Future<HubRead> read(
    String user,
    String home,
    String key,
    Future<Map<String, dynamic>> Function() fetch,
    bool Function() current,
    void Function(Map<String, dynamic>) validate,
  ) async {
    try {
      final data = await fetch();
      validate(data);
      final time = DateTime.now();
      bool failed = false;
      if (current()) {
        try {
          await cache.write(user, home, 'hub.$key', {
            'data': data,
            'saved_at': time.toIso8601String(),
          });
        } catch (_) {
          failed = true;
        }
      }
      return HubRead(data, time, cacheError: failed);
    } on NetworkException {
      if (!current()) rethrow;
      final saved = await cache.read(user, home, 'hub.$key');
      if (saved == null) rethrow;
      final data = Map<String, dynamic>.from(saved['data'] as Map);
      validate(data);
      return HubRead(
        data,
        DateTime.parse(saved['saved_at'] as String),
        cached: true,
      );
    }
  }
}
