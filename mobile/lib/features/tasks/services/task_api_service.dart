import 'dart:convert';
import 'dart:typed_data';

import '../../../core/network/api_client.dart';

String taskToday() => DateTime.now().toIso8601String().substring(0, 10);

class TaskApiService {
  TaskApiService(this.api);
  final ApiClient api;
  String root(String household) =>
      '/api/v1/households/${Uri.encodeComponent(household)}';
  String path(String household, [String suffix = '']) =>
      '${root(household)}/tasks$suffix';
  Future<Map<String, dynamic>> list(
    String h,
    Map<String, String> query,
  ) async => await api.get(
    '${path(h)}?${Uri(queryParameters: {'as_of': taskToday(), ...query}).query}',
  ) as Map<String, dynamic>;
  Future<Map<String, dynamic>> summary(String h) async =>
      await api.get('${path(h, '/summary')}?as_of=${taskToday()}')
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
      await api.patch(path(h, '/$id/$action'), body: fields)
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> archive(
    String h,
    String id,
    int revision,
    bool restore,
  ) async =>
      (restore
              ? await api.post(
                  path(h, '/$id/restore'),
                  body: {'expected_revision': revision},
                )
              : await api.delete(
                  '${path(h, '/$id')}?expected_revision=$revision',
                ))
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> section(
    String h,
    String id,
    String section,
    int page,
  ) async =>
      await api.get('${path(h, '/$id/$section')}?page=$page&page_size=20')
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> comment(
    String h,
    String id,
    int revision,
    String body, {
    String? commentId,
    int? commentRevision,
  }) async =>
      (commentId == null
              ? await api.post(
                  path(h, '/$id/comments'),
                  body: {'expected_revision': revision, 'body': body},
                )
              : await api.patch(
                  path(h, '/$id/comments/$commentId'),
                  body: {
                    'expected_revision': revision,
                    'expected_comment_revision': commentRevision,
                    'body': body,
                  },
                ))
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> deleteComment(
    String h,
    String id,
    int revision,
    String commentId,
    int commentRevision,
  ) async => await api.delete(
    '${path(h, '/$id/comments/$commentId')}?expected_revision=$revision&expected_comment_revision=$commentRevision',
  ) as Map<String, dynamic>;
  Future<Map<String, dynamic>> upload(
    String h,
    String id,
    int revision,
    Uint8List bytes,
    String? commentId,
  ) async => await api.post(
    path(h, '/$id/attachments'),
    body: {
      'expected_revision': revision,
      'comment_id': commentId,
      'data_base64': base64Encode(bytes),
    },
  ) as Map<String, dynamic>;
  Future<Map<String, dynamic>> removePhoto(
    String h,
    String id,
    int revision,
    String attachmentId,
  ) async => await api.delete(
    '${path(h, '/$id/attachments/$attachmentId')}?expected_revision=$revision',
  ) as Map<String, dynamic>;
  Future<Map<String, dynamic>> photoURL(
    String h,
    String id,
    String attachmentId,
  ) async =>
      await api.get(path(h, '/$id/attachments/$attachmentId/url'))
          as Map<String, dynamic>;
  Future<List<Map<String, dynamic>>> members(String h) async {
    final result = <Map<String, dynamic>>[];
    while (true) {
      final batch = (await api.get(
        '${root(h)}/members?limit=100&offset=${result.length}',
      ) as List).cast<Map<String, dynamic>>();
      result.addAll(batch);
      if (batch.length < 100) return result;
    }
  }

  Future<Map<String, dynamic>> inventory(
    String h,
    String search,
    int page,
  ) async => await api.get(
    '${root(h)}/inventory?${Uri(queryParameters: {'search': search, 'page': '$page', 'page_size': '20'}).query}',
  ) as Map<String, dynamic>;
  Future<Map<String, dynamic>> related(String h, String itemId) async =>
      await api.get('${root(h)}/inventory/$itemId/tasks?page_size=5')
          as Map<String, dynamic>;
}
