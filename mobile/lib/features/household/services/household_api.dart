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

  Future<List<dynamic>> members(String id, int offset) async =>
      await api.get('/api/v1/households/$id/members?limit=50&offset=$offset')
          as List<dynamic>;
  Future<void> update(String id, String name, String? description) async {
    await api.patch(
      '/api/v1/households/$id',
      body: {'name': name, 'description': description},
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

  Future<Map<String, dynamic>> create(String name, String? description) async {
    final result = await api.post(
      '/api/v1/households',
      body: {'name': name, 'description': description},
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
