import '../../../core/network/api_client.dart';

class HouseholdHubApi {
  HouseholdHubApi(this.api);
  final ApiClient api;
  String household(String h, String suffix) =>
      '/api/v1/households/${Uri.encodeComponent(h)}/$suffix';
  String query(Map<String, String> values) =>
      Uri(queryParameters: values).query;
  Future<Map<String, dynamic>> get(String path) async =>
      Map<String, dynamic>.from(await api.get(path) as Map);
  Future<Map<String, dynamic>> dashboard(String h) =>
      get(household(h, 'dashboard'));
  Future<Map<String, dynamic>> activity(
    String h,
    Map<String, String> filters,
  ) => get('${household(h, 'activity')}?${query(filters)}');
  Future<Map<String, dynamic>> notifications(
    String h,
    Map<String, String> filters,
  ) => get('/api/v1/notifications?${query({'household_id': h, ...filters})}');
  Future<Map<String, dynamic>> notification(String id) =>
      get('/api/v1/notifications/${Uri.encodeComponent(id)}');
  Future<Map<String, dynamic>> count(String h) =>
      get('/api/v1/notifications/unread-count?${query({'household_id': h})}');
  Future<Map<String, dynamic>> preferences(String h) =>
      get(household(h, 'notification-preferences'));
  Future<Map<String, dynamic>> updatePreferences(
    String h,
    Map<String, bool> fields,
  ) async => Map<String, dynamic>.from(
    await api.patch(household(h, 'notification-preferences'), body: fields)
        as Map,
  );
  Future<void> mark(String id, String action) async {
    await api.patch('/api/v1/notifications/${Uri.encodeComponent(id)}/$action');
  }

  Future<void> markAll(String h) async {
    await api.post(
      '/api/v1/notifications/mark-all-read',
      body: {'household_id': h},
    );
  }

  Future<void> register(String token, String installation) async {
    await api.post(
      '/api/v1/devices/fcm-token',
      body: {
        'token': token,
        'device_identifier': installation,
        'platform': 'android',
      },
    );
  }

  Future<void> revoke(String installation) async {
    await api.delete(
      '/api/v1/devices/fcm-token',
      body: {'device_identifier': installation},
    );
  }
}
