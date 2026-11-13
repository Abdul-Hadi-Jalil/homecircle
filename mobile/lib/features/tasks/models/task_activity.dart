class TaskActivity {
  TaskActivity(Map<String, dynamic> json) : data = Map.unmodifiable(json);
  final Map<String, dynamic> data;
  String get action => data['action'] as String;
  String? get actorName => data['actor_name'] as String?;
  Map<String, dynamic> get changes => data['changes'] as Map<String, dynamic>;
}
