import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mock_widgets.dart';
import '../models/household_task.dart';
import 'task_widgets.dart';

/// Priority pill (UI/tasks_requests_overview).
class PriorityBadge extends StatelessWidget {
  const PriorityBadge(this.priority, {super.key});
  final TaskPriority priority;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (priority) {
      TaskPriority.urgent => (const Color(0xFFFFDAD6), AppColors.danger),
      TaskPriority.high => (AppColors.tertiaryFixed, AppColors.tertiary),
      TaskPriority.normal => (AppColors.primaryFixed, AppColors.primary),
      TaskPriority.low => (AppColors.surfaceHighest, AppColors.muted),
    };
    return AppPill(
      taskLabel(context, priority.name),
      bg: bg,
      fg: fg,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
    );
  }
}

/// Status pill (Open / In Progress / ...).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final TaskStatus status;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      TaskStatus.completed => (
        AppColors.secondaryContainer,
        AppColors.onSecondaryContainer,
      ),
      TaskStatus.blocked => (const Color(0xFFFFDAD6), AppColors.danger),
      TaskStatus.inProgress => (AppColors.primaryFixed, AppColors.primary),
      TaskStatus.cancelled => (AppColors.surfaceContainer, AppColors.muted),
      TaskStatus.open => (AppColors.surfaceContainer, AppColors.muted),
    };
    return AppPill(
      taskLabel(context, statusWire(status)),
      bg: bg,
      fg: fg,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 2,
      ),
    );
  }
}

/// "Today", "Tomorrow", a weekday this week, or "Mon, Oct 28".
String taskDueText(BuildContext context, AppLocalizations l, String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  final today = DateUtils.dateOnly(DateTime.now());
  final day = DateUtils.dateOnly(date);
  final diff = day.difference(today).inDays;
  final locale = Localizations.localeOf(context).languageCode;
  if (diff == 0) return l.taskToday;
  if (diff == 1) return l.taskTomorrow;
  if (diff > 1 && diff < 7) return DateFormat.EEEE(locale).format(day);
  return DateFormat.MMMEd(locale).format(day);
}

const _avatarPalette = [
  (AppColors.primary, Colors.white),
  (AppColors.secondary, Colors.white),
  (AppColors.tertiaryFixed, AppColors.onTertiaryFixed),
  (AppColors.primaryContainer, Colors.white),
];

(Color, Color) taskAvatarColors(String name) =>
    _avatarPalette[name.codeUnits.fold<int>(0, (a, b) => a + b) %
        _avatarPalette.length];

/// Task list card with the footer action strip from the mockup.
class TaskCard extends StatelessWidget {
  const TaskCard({required this.task, required this.onTap, super.key});
  final HouseholdTask task;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final assignee = task.assigneeName?.trim();
    final creator = task.creatorName?.trim();
    final who = assignee != null && assignee.isNotEmpty
        ? l.taskAssignedToName(assignee)
        : task.assignedTo != null
        ? l.taskFormerMember
        : creator != null && creator.isNotEmpty
        ? l.taskRequestedBy(creator)
        : l.taskUnassigned;
    final avatarName = assignee != null && assignee.isNotEmpty
        ? assignee
        : creator ?? '?';
    final (avBg, avFg) = taskAvatarColors(avatarName);
    final urgent = task.priority == TaskPriority.urgent || task.overdue();
    final action = task.terminal
        ? null
        : task.assignedTo == null
        ? (l.taskActionTake, Icons.person_add_alt)
        : task.status == TaskStatus.inProgress
        ? (l.taskActionUpdate, Icons.check_circle_outline)
        : (l.taskActionComplete, Icons.check_circle_outline);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconTile(
                          icon: taskKindIcon(task.kind),
                          bg: AppColors.surfaceContainer,
                          fg: AppColors.primary,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: AppText.headlineSm.copyWith(
                                  color: AppColors.text,
                                ),
                              ),
                              Text(
                                taskLabel(context, task.kind.name),
                                style: AppText.labelMd.copyWith(
                                  color: AppColors.muted,
                                  letterSpacing: 0,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        PriorityBadge(task.priority),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        InitialsAvatar(
                          avatarName,
                          size: 32,
                          bg: avBg,
                          fg: avFg,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            who,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyMd.copyWith(
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        if (task.dueDate != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            urgent
                                ? Icons.schedule
                                : Icons.calendar_today_outlined,
                            size: 16,
                            color: urgent ? AppColors.danger : AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              l.taskDueLabel(
                                taskDueText(context, l, task.dueDate!),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.labelMd.copyWith(
                                color: urgent
                                    ? AppColors.danger
                                    : AppColors.muted,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                color: AppColors.surfaceLow.withAlpha(140),
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatusBadge(task.status),
                    if (action != null)
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(action.$2, size: 18, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                action.$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.labelLg.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
