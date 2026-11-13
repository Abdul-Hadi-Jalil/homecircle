enum TaskKind { repair, chore, general, shopping }

enum TaskPriority { low, normal, high, urgent }

enum TaskStatus { open, inProgress, blocked, completed, cancelled }

String statusWire(TaskStatus status) =>
    status == TaskStatus.inProgress ? 'in_progress' : status.name;

class HouseholdTask {
  HouseholdTask(Map<String, dynamic> json) : data = Map.unmodifiable(json) {
    id;
    householdId;
    title;
    kind;
    priority;
    status;
    revision;
  }
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get householdId => data['household_id'] as String;
  String get title => data['title'] as String;
  TaskKind get kind => TaskKind.values.byName(data['task_type'] as String);
  TaskPriority get priority =>
      TaskPriority.values.byName(data['priority'] as String);
  TaskStatus get status =>
      TaskStatus.values.singleWhere((v) => statusWire(v) == data['status']);
  int get revision => data['revision'] as int;
  String? get assignedTo => data['assigned_to'] as String?;
  String? get assigneeName => data['assignee_name'] as String?;
  String? get creatorName => data['creator_name'] as String?;
  String? get linkedItemId => data['linked_inventory_item_id'] as String?;
  String? get linkedItemName => data['linked_inventory_name'] as String?;
  bool get linkedDurable => data['linked_inventory_type'] == 'durable';
  String? get dueDate => data['due_date'] as String?;
  bool get archived => data['deleted_at'] != null;
  bool get terminal =>
      status == TaskStatus.completed || status == TaskStatus.cancelled;
  String get description => data['description'] as String? ?? '';
  bool overdue([DateTime? now]) {
    if (archived || terminal || dueDate == null) return false;
    final today = now ?? DateTime.now();
    return DateTime.parse(dueDate!)
        .isBefore(DateTime(today.year, today.month, today.day));
  }
}

class TaskPage {
  TaskPage(Map<String, dynamic> json)
    : items = (json['items'] as List)
          .map((v) => HouseholdTask(v as Map<String, dynamic>))
          .toList(),
      total = json['total'] as int,
      page = json['page'] as int;
  final List<HouseholdTask> items;
  final int total, page;
}
