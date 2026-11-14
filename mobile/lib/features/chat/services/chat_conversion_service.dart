import '../../../core/network/api_client.dart';

class ChatConversionService {
  ChatConversionService(this.api);
  final ApiClient api;
  Future<Map<String, dynamic>> create(
    String household,
    String type,
    Map<String, dynamic> fields,
    Map<String, dynamic> source,
  ) async => await api.post(
    '/api/v1/households/${Uri.encodeComponent(household)}/chat/messages/${Uri.encodeComponent(source['_chat_message_id'] as String)}/create-task',
    body: {
      'expected_revision': source['_chat_revision'],
      'client_request_id': source['_chat_request_id'],
      'task_type': type,
      'fields': {...fields}..remove('task_type'),
    },
  ) as Map<String, dynamic>;
}
