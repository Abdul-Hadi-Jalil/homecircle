import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/household_task.dart';

extension TaskCopy on BuildContext {
  AppLocalizations get taskCopy => AppLocalizations.of(this)!;
}

String taskLabel(BuildContext context, String value) {
  final l = context.taskCopy;
  return switch (value) {
    'repair' => l.taskRepair,
    'chore' => l.taskChore,
    'general' => l.taskGeneral,
    'shopping' => l.taskShoppingSoon,
    'low' => l.taskLow,
    'normal' => l.taskNormal,
    'high' => l.taskHigh,
    'urgent' => l.taskUrgent,
    'open' => l.taskOpen,
    'in_progress' => l.taskInProgress,
    'blocked' => l.taskBlocked,
    'completed' => l.taskCompleted,
    'cancelled' => l.taskCancelled,
    _ => value,
  };
}

String taskError(BuildContext context, String? code) {
  final l = context.taskCopy;
  return switch (code) {
    'local_storage' => l.chatCacheError,
    'network' => l.taskNetworkError,
    'revision_conflict' => l.taskConflict,
    'already_claimed' => l.taskAlreadyClaimed,
    'forbidden' || 'unauthorized' => l.taskForbidden,
    'not_found' => l.taskNotAvailable,
    'invalid_reference' => l.taskInvalidReference,
    'explicit_reopen_required' || 'invalid_transition' => l.taskReopenRequired,
    'invalid_photo' || 'photo_too_large' => l.taskPhotoLimit,
    'inventory_condition_failed' => l.taskConditionFailed,
    'task_saved_photo_failed' => l.taskPhotoPartial,
    'comment_photo_failed' => l.taskCommentPhotoPartial,
    'photo_unavailable' => l.taskPhotoError,
    _ => l.taskError,
  };
}

String taskTimestamp(BuildContext context, dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null
      ? ''
      : DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
            .add_jm()
            .format(date.toLocal());
}

class TaskNotice extends StatelessWidget {
  const TaskNotice(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class PriorityBadge extends StatelessWidget {
  const PriorityBadge(this.priority, {super.key});
  final TaskPriority priority;
  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      TaskPriority.urgent => AppColors.danger,
      TaskPriority.high => AppColors.warning,
      TaskPriority.normal => AppColors.primary,
      TaskPriority.low => AppColors.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        taskLabel(context, priority.name),
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final TaskStatus status;
  @override
  Widget build(BuildContext context) {
    final color = status == TaskStatus.completed
        ? AppColors.success
        : status == TaskStatus.blocked
        ? AppColors.danger
        : status == TaskStatus.inProgress
        ? AppColors.warning
        : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        taskLabel(context, statusWire(status)),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  const TaskCard({required this.task, required this.onTap, super.key});
  final HouseholdTask task;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      taskKindIcon(task.kind),
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          taskLabel(context, task.kind.name),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PriorityBadge(task.priority),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.lightBlue,
                    child: Icon(
                      Icons.person_outline,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.assigneeName?.isNotEmpty == true
                          ? task.assigneeName!
                          : task.assignedTo == null
                          ? l.taskUnassigned
                          : l.taskFormerMember,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (task.dueDate != null)
                    Text(
                      task.dueDate!,
                      style: TextStyle(
                        color: task.overdue()
                            ? AppColors.danger
                            : AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const Divider(height: 28),
              Row(
                children: [
                  StatusBadge(task.status),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
              if (task.overdue())
                Text(
                  l.taskOverdue,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData taskKindIcon(TaskKind kind) => switch (kind) {
  TaskKind.repair => Icons.build_outlined,
  TaskKind.chore => Icons.cleaning_services_outlined,
  TaskKind.general => Icons.chat_bubble_outline,
  TaskKind.shopping => Icons.shopping_cart_outlined,
};

class TaskSection extends StatelessWidget {
  const TaskSection({
    required this.children,
    this.title,
    this.tinted = false,
    super.key,
  });
  final List<Widget> children;
  final String? title;
  final bool tinted;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    color: tinted ? AppColors.lightBlue : Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
          ],
          ...children,
        ],
      ),
    ),
  );
}

class TaskInfoCell extends StatelessWidget {
  const TaskInfoCell({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

DropdownButtonFormField<String> taskDropdown(
  String label,
  String? value,
  List<(String, String)> options,
  ValueChanged<String?>? onChanged,
) => DropdownButtonFormField<String>(
  key: ValueKey('$label-$value'),
  initialValue: options.any((e) => e.$1 == value) ? value : '',
  decoration: InputDecoration(labelText: label),
  isExpanded: true,
  items: options
      .map(
        (e) => DropdownMenuItem(
          value: e.$1,
          child: Text(e.$2, overflow: TextOverflow.ellipsis),
        ),
      )
      .toList(),
  onChanged: onChanged,
);

class AssigneeSelector extends StatelessWidget {
  const AssigneeSelector({
    required this.members,
    required this.value,
    required this.onChanged,
    super.key,
  });
  final List<Map<String, dynamic>> members;
  final String? value;
  final ValueChanged<String?>? onChanged;
  @override
  Widget build(BuildContext context) =>
      taskDropdown(context.taskCopy.taskAssignee, value ?? '', [
        ('', context.taskCopy.taskUnassigned),
        if (value != null && !members.any((e) => e['user_id'] == value))
          (value!, context.taskCopy.taskFormerMember),
        ...members.map(
          (e) => (
            e['user_id'] as String,
            (e['display_name'] as String?)?.isNotEmpty == true
                ? e['display_name'] as String
                : context.taskCopy.taskFormerMember,
          ),
        ),
      ], onChanged == null ? null : (v) => onChanged!(v == '' ? null : v));
}

Future<bool> confirmTask(
  BuildContext context,
  String title, {
  String? message,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.taskCopy.taskDismiss),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.taskCopy.taskConfirm),
          ),
        ],
      ),
    ) ??
    false;
