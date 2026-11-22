import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../models/household_task.dart';

export 'task_cards.dart';

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
}) => showConfirmDialog(
  context,
  title: title,
  message: message,
  confirmLabel: context.taskCopy.taskConfirm,
  cancelLabel: context.taskCopy.taskDismiss,
  icon: Icons.help_outline,
);
