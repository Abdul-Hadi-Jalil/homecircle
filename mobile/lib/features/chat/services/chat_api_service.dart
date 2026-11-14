import 'dart:convert';

import '../../../core/network/api_client.dart';

class ChatApiService {
  ChatApiService(this.api);
  final ApiClient api;
  Future<Map<String, dynamic>> task(String h, String id) async => await api.get(
    '/api/v1/households/${Uri.encodeComponent(h)}/tasks/${Uri.encodeComponent(id)}',
  ) as Map<String, dynamic>;
  String path(String home, [String suffix = '']) =>
      '/api/v1/households/${Uri.encodeComponent(home)}/chat$suffix';
  Future<Map<String, dynamic>> history(
    String h, {
    String? before,
  }) async => await api.get(
    '${path(h, '/messages')}?${Uri(queryParameters: {'limit': '30', 'before': ?before}).query}',
  ) as Map<String, dynamic>;
  Future<Map<String, dynamic>> changes(String h, int after) async =>
      await api.get('${path(h, '/changes')}?after=$after&limit=100')
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> send(
    String h,
    Map<String, dynamic> body,
  ) async =>
      await api.post(path(h, '/messages'), body: body) as Map<String, dynamic>;
  Future<Map<String, dynamic>> edit(
    String h,
    String id,
    int revision,
    String body,
  ) async => await api.patch(
    path(h, '/messages/$id'),
    body: {'expected_revision': revision, 'body': body},
  ) as Map<String, dynamic>;
  Future<Map<String, dynamic>> delete(
    String h,
    String id,
    int revision,
  ) async => await api.delete(
    '${path(h, '/messages/$id')}?expected_revision=$revision',
  ) as Map<String, dynamic>;
  Future<Map<String, dynamic>> react(
    String h,
    String id,
    String emoji,
    bool remove,
  ) async =>
      (remove
              ? await api.delete(
                  path(
                    h,
                    '/messages/$id/reactions/${Uri.encodeComponent(emoji)}',
                  ),
                )
              : await api.put(
                  path(h, '/messages/$id/reactions'),
                  body: {'emoji': emoji},
                ))
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> upload(
    String h,
    String clientId,
    String attachmentId,
    List<int> bytes,
  ) async => await api.post(
    path(h, '/attachments'),
    body: {
      'client_message_id': clientId,
      'attachment_id': attachmentId,
      'data_base64': base64Encode(bytes),
    },
  ) as Map<String, dynamic>;
  Future<Map<String, dynamic>> imageUrl(String h, String id) async =>
      await api.get(path(h, '/attachments/$id/url')) as Map<String, dynamic>;
  Future<Map<String, dynamic>> tasks(
    String h,
    String search,
    int page,
  ) async => await api.get(
    '/api/v1/households/${Uri.encodeComponent(h)}/tasks?${Uri(queryParameters: {'search': search, 'page': '$page', 'page_size': '20'}).query}',
  ) as Map<String, dynamic>;
}
