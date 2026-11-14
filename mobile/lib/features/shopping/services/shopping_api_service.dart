import '../../../core/network/api_client.dart';

class ShoppingApiService {
  ShoppingApiService(this.api);
  final ApiClient api;
  String path(String household, [String suffix = '']) =>
      '/api/v1/households/${Uri.encodeComponent(household)}/shopping$suffix';
  Future<Map<String, dynamic>> list(
    String h,
    Map<String, String> query, {
    String suffix = '',
  }) async =>
      await api.get('${path(h, suffix)}?${Uri(queryParameters: query).query}')
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> detail(String h, String id) async =>
      await api.get(path(h, '/$id')) as Map<String, dynamic>;
  Future<Map<String, dynamic>> save(
    String h,
    String? id,
    Map<String, dynamic> fields,
  ) async =>
      (id == null
              ? await api.post(path(h), body: fields)
              : await api.patch(path(h, '/$id'), body: fields))
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> action(
    String h,
    String id,
    String action,
    Map<String, dynamic> fields,
  ) async =>
      (action == 'assignment'
              ? await api.patch(path(h, '/$id/$action'), body: fields)
              : await api.post(path(h, '/$id/$action'), body: fields))
          as Map<String, dynamic>;
}
