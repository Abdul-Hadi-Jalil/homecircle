import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';

class HouseholdApi {
  HouseholdApi(this.api);
  final ApiClient api;

  Future<Map<String, dynamic>> updateProfile(String name) async =>
      await api.patch('/api/v1/me', body: {'display_name': name})
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> preview(String code) async =>
      await api.post('/api/v1/invites/preview', body: {'code': code})
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> redeem(String code) async =>
      await api.post('/api/v1/invites/redeem', body: {'code': code})
          as Map<String, dynamic>;
  Future<List<dynamic>> invites(String id) async =>
      await api.get('/api/v1/households/$id/invites') as List<dynamic>;
  Future<Map<String, dynamic>> issue(String id) async =>
      await api.post('/api/v1/households/$id/invites') as Map<String, dynamic>;
  Future<void> revoke(String id, String inviteId) async {
    await api.delete('/api/v1/households/$id/invites/$inviteId');
  }

  /// Total tasks matching [query] (only the count is read).
  Future<int> taskTotal(String household, Map<String, String> query) async {
    final result = await api.get(
      '/api/v1/households/$household/tasks?'
      '${Uri(queryParameters: {'page_size': '1', ...query}).query}',
    ) as Map<String, dynamic>;
    return (result['total'] as num?)?.toInt() ?? 0;
  }

  Future<void> setMemberRole(String id, String userId, String role) async {
    await api.patch(
      '/api/v1/households/$id/members/$userId',
      body: {'role': role},
    );
  }

  Future<void> removeMember(String id, String userId) async {
    await api.delete('/api/v1/households/$id/members/$userId');
  }

  Future<void> leave(String id) async {
    await api.post('/api/v1/households/$id/leave');
  }

  Future<void> deleteHousehold(String id) async {
    await api.delete('/api/v1/households/$id');
  }

  Future<List<dynamic>> members(String id, int offset) async =>
      await api.get('/api/v1/households/$id/members?limit=50&offset=$offset')
          as List<dynamic>;
  Future<void> update(
    String id,
    String name,
    String? description, {
    String? avatarKey,
  }) async {
    await api.patch(
      '/api/v1/households/$id',
      body: {
        'name': name,
        'description': description,
        'avatar_key': ?avatarKey,
      },
    );
  }

  Future<Map<String, dynamic>> detail(String householdId) async {
    final result = await api.get(
      '/api/v1/households/${Uri.encodeComponent(householdId)}',
    );
    if (result is! Map<String, dynamic>) throw const InvalidResponseException();
    return result;
  }

  Future<List<dynamic>> memberships() async {
    final result = await api.get('/api/v1/households');
    if (result is! List<dynamic>) throw const InvalidResponseException();
    return result;
  }

  Future<Map<String, dynamic>> create(
    String name,
    String? description, {
    String? avatarKey,
  }) async {
    final result = await api.post(
      '/api/v1/households',
      body: {
        'name': name,
        'description': description,
        'avatar_key': ?avatarKey,
      },
    );
    if (result is! Map<String, dynamic>) throw const InvalidResponseException();
    return result;
  }

  Future<Map<String, dynamic>> me() async {
    final result = await api.get('/api/v1/me');
    if (result is! Map<String, dynamic>) throw const InvalidResponseException();
    return result;
  }
}
