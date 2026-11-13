import '../../../core/network/api_client.dart';

class InventoryApi {
  InventoryApi(this.api);
  final ApiClient api;
  String path(String household, [String suffix = '']) =>
      '/api/v1/households/${Uri.encodeComponent(household)}/inventory$suffix';
  Future<Map<String, dynamic>> list(
    String household,
    Map<String, String> filters,
  ) async =>
      await api.get('${path(household)}?${Uri(queryParameters: filters).query}')
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> detail(String household, String id) async =>
      await api.get(path(household, '/$id')) as Map<String, dynamic>;
  Future<List<dynamic>> categories(String household) async =>
      await api.get(path(household, '/categories')) as List<dynamic>;
  Future<Map<String, dynamic>> summary(String household) async =>
      await api.get(path(household, '/summary')) as Map<String, dynamic>;
  Future<Map<String, dynamic>> activity(
    String household,
    String id,
    int page,
  ) async =>
      await api.get('${path(household, '/$id/activity')}?page=$page')
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> save(
    String household,
    String? id,
    Map<String, dynamic> fields,
  ) async =>
      (id == null
              ? await api.post(path(household), body: fields)
              : await api.patch(path(household, '/$id'), body: fields))
          as Map<String, dynamic>;
}
