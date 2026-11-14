class ShoppingSummary {
  const ShoppingSummary(this.data);
  final Map<String, dynamic> data;
  int get active => data['active'] as int? ?? 0;
  int get purchased => data['purchased'] as int? ?? 0;
  int get total => data['total'] as int? ?? 0;
  int get highPriority => data['high_priority'] as int? ?? 0;
  int get assignedToMe => data['assigned_to_me'] as int? ?? 0;
  double get progress => total == 0 ? 0 : (purchased / total).clamp(0, 1);
}
