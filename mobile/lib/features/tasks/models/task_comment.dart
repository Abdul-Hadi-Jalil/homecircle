class TaskComment {
  TaskComment(Map<String, dynamic> json) : data = Map.unmodifiable(json);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get taskId => data['task_id'] as String;
  String get householdId => data['household_id'] as String;
  String? get authorId => data['author_user_id'] as String?;
  String? get authorName => data['author_name'] as String?;
  String get body => data['body'] as String;
  int get revision => data['revision'] as int;
}

class TaskAttachment {
  TaskAttachment(Map<String, dynamic> json) : data = Map.unmodifiable(json);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get householdId => data['household_id'] as String;
  String get taskId => data['task_id'] as String;
  String? get commentId => data['comment_id'] as String?;
  String? get uploaderId => data['uploaded_by'] as String?;
}
