import '../../../core/errors/app_exception.dart';
import '../models/chat_message.dart';
import '../services/chat_api_service.dart';
import 'chat_cache.dart';

class ChatRepository {
  ChatRepository(this.service, this.cache);
  final ChatApiService service;
  final ChatCache cache;
  ChatMessage message(Map<String, dynamic> row, String home) {
    if (row['household_id'] != home) throw const InvalidResponseException();
    for (final item in row['attachments'] as List? ?? []) {
      if (item['household_id'] != home || item['message_id'] != row['id']) {
        throw const InvalidResponseException();
      }
    }
    final reply = row['reply_preview'];
    if (reply is Map &&
        (reply['household_id'] != home ||
            reply['id'] != row['reply_to_message_id'])) {
      throw const InvalidResponseException();
    }
    for (final task in [
      if (row['task'] is Map) row['task'],
      ...row['converted_tasks'] as List? ?? [],
    ]) {
      if (task['household_id'] != home) throw const InvalidResponseException();
    }
    return ChatMessage(row);
  }

  List<ChatMessage> messages(Map<String, dynamic> page, String home) =>
      (page['items'] as List)
          .map((row) => message(row as Map<String, dynamic>, home))
          .toList();
}
