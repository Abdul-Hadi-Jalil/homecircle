import 'dart:math';

String chatUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class ChatMessage {
  ChatMessage(Map<String, dynamic> json) : data = Map.unmodifiable(json) {
    id;
    household;
    sender;
    revision;
    version;
    created;
    if (!['text', 'image', 'task_share', 'system'].contains(type)) {
      throw const FormatException('Unknown message type');
    }
  }
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get household => data['household_id'] as String;
  String get sender => data['sender_user_id'] as String;
  String get clientId => data['client_message_id'] as String;
  String get type => data['message_type'] as String;
  String? get senderName => data['sender_name'] as String?;
  bool get deleted => data['deleted_at'] != null;
  String get body => deleted ? '' : data['body'] as String? ?? '';
  int get revision => data['revision'] as int;
  int get version => data['version'] as int;
  DateTime get created => DateTime.parse(data['created_at'] as String);
  bool get edited => data['edited_at'] != null;
  List<Map<String, dynamic>> get reactions => deleted
      ? []
      : (data['reactions'] as List? ?? []).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get attachments => deleted
      ? []
      : (data['attachments'] as List? ?? []).cast<Map<String, dynamic>>();
  Map<String, dynamic>? get reply =>
      deleted ? null : data['reply_preview'] as Map<String, dynamic>?;
  List<Map<String, dynamic>> get tasks => deleted
      ? []
      : [
          if (data['task'] is Map) data['task'] as Map<String, dynamic>,
          ...(data['converted_tasks'] as List? ?? [])
              .cast<Map<String, dynamic>>(),
        ];
}

enum ChatSendState { sending, sent, failed }

class PendingChatMessage {
  PendingChatMessage(
    this.clientId,
    this.body, {
    this.replyId,
    this.image,
    this.attachmentId,
    this.linkedTaskId,
    bool requiresImage = false,
  }) : imageRequired = requiresImage || image != null || attachmentId != null;
  final String clientId, body;
  final String? replyId, linkedTaskId;
  final bool imageRequired;
  List<int>? image;
  String? attachmentId;
  bool uploaded = false;
  ChatSendState state = ChatSendState.sending;
  String? error;
  Map<String, dynamic> get payload => {
    'client_message_id': clientId,
    'body': body.trim().isEmpty ? null : body.trim(),
    'message_type': linkedTaskId != null
        ? 'task_share'
        : imageRequired
        ? 'image'
        : 'text',
    'reply_to_message_id': replyId,
    'linked_task_id': linkedTaskId,
    'attachment_ids': [if (attachmentId != null) attachmentId],
  };
}
