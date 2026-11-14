import 'chat_message.dart';

class ChatTaskSource {
  ChatTaskSource({
    required this.messageId,
    required this.household,
    required this.body,
    required this.revision,
    String? requestId,
  }) : requestId = requestId ?? chatUuid();
  final String messageId, household, body, requestId;
  final int revision;
  String get suggestedTitle =>
      String.fromCharCodes(body.split('\n').first.runes.take(100));
  Map<String, dynamic> get fields => {
    '_chat_message_id': messageId,
    '_chat_revision': revision,
    '_chat_request_id': requestId,
  };
}
