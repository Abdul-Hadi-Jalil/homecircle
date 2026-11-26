import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/mock_widgets.dart';
import '../../tasks/widgets/task_widgets.dart';
import 'hub_widgets.dart';

/// "Needs Attention" / "Upcoming" card from the home mockup.
class HubRecordCard extends StatelessWidget {
  const HubRecordCard(this.record, {super.key});
  final Map<String, dynamic> record;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final type =
        record['task_type'] as String? ?? record['entity_type'] as String;
    final status = record['status'] as String;
    final priority = record['priority'] as String?;
    final tone = _tone(priority);
    final kind = switch (type) {
      'repair' => l.hubKindRepair,
      'shopping' => l.hubKindShopping,
      'chore' => l.hubKindChore,
      'inventory' => l.hubKindInventory,
      _ => l.hubKindGeneral,
    };
    final assignee = record['assignee_name'] as String?;
    final statusText = status == 'out_of_stock'
        ? l.hubOutStock
        : status == 'low_stock'
        ? l.hubLowStock
        : status == 'broken'
        ? l.hubBroken
        : status == 'needs_repair'
        ? l.hubNeedsRepair
        : taskLabel(context, status);
    final due = record['due_date'] as String?;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openHubEntity(
          context,
          record['entity_type'] as String,
          record['id'] as String,
          record['household_id'] as String,
        ),
        child: Ink(
          padding: const EdgeInsetsDirectional.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 2),
                child: IconTile(
                  icon: _kindIcon(type),
                  bg: tone.iconBg,
                  fg: tone.fg,
                  size: 44,
                  iconSize: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.titleMd.copyWith(
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        if (priority != null) ...[
                          const SizedBox(width: 4),
                          AppPill(
                            taskLabel(context, priority),
                            bg: tone.pillBg,
                            fg: tone.pillFg,
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        kind,
                        if (assignee != null) l.hubAssignedTo(assignee),
                      ].join(' • '),
                      style: AppText.bodySm.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Flexible(
                          child: AppPill(
                            l.hubStatusLabel(statusText),
                            bg: status == 'in_progress'
                                ? AppColors.surfaceContainer
                                : AppColors.surfaceLow,
                            fg: status == 'in_progress'
                                ? AppColors.primary
                                : AppColors.muted,
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                          ),
                        ),
                        if (due != null) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '• ${_due(context, l, due)}',
                              overflow: TextOverflow.ellipsis,
                              style: AppText.labelSm.copyWith(
                                color: const Color(0xFF747686),
                                letterSpacing: 0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
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

  String _due(BuildContext context, AppLocalizations l, String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return l.hubDueOn(value);
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(date);
    if (day == today) return l.hubDueToday;
    if (day == today.add(const Duration(days: 1))) return l.hubDueTomorrow;
    return l.hubDueOn(
      MaterialLocalizations.of(context).formatShortMonthDay(day),
    );
  }

  IconData _kindIcon(String type) => switch (type) {
    'repair' => Icons.build,
    'shopping' => Icons.shopping_cart,
    'chore' => Icons.cleaning_services,
    'inventory' => Icons.inventory_2,
    _ => Icons.lightbulb,
  };

  ({Color iconBg, Color fg, Color pillBg, Color pillFg}) _tone(
    String? priority,
  ) => switch (priority) {
    'urgent' => (
      iconBg: const Color(0x66FFDAD6),
      fg: AppColors.danger,
      pillBg: const Color(0xFFFFDAD6),
      pillFg: AppColors.danger,
    ),
    'high' => (
      iconBg: const Color(0x80FFDDB5),
      fg: AppColors.tertiary,
      pillBg: AppColors.tertiaryFixed,
      pillFg: AppColors.tertiary,
    ),
    _ => (
      iconBg: AppColors.surfaceContainer,
      fg: AppColors.primary,
      pillBg: AppColors.primaryFixed,
      pillFg: AppColors.primary,
    ),
  };
}

/// Timeline card used for "Recent Activity".
class ActivityTimeline extends StatelessWidget {
  const ActivityTimeline(this.events, {super.key});
  final List<Map<String, dynamic>> events;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    return AppCard(
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++)
            _ActivityRow(event: events[i], last: i == events.length - 1, l: l),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.event,
    required this.last,
    required this.l,
  });
  final Map<String, dynamic> event;
  final bool last;
  final AppLocalizations l;
  @override
  Widget build(BuildContext context) {
    final category = event['category'] as String;
    final actor = (event['actor_display_name'] as String?)?.trim();
    final name = actor == null || actor.isEmpty ? l.hubFormer : actor;
    final when = DateTime.tryParse(event['created_at'] as String? ?? '');
    final (bg, fg) = switch (category) {
      'shopping' => (const Color(0x8082F9C1), AppColors.secondary),
      'repairs' || 'inventory' => (const Color(0x99FFDDB5), AppColors.tertiary),
      _ => (AppColors.surfaceContainer, AppColors.primary),
    };
    return InkWell(
      onTap: () => openHubEntity(
        context,
        event['entity_type'] as String,
        event['entity_id'] as String,
        event['household_id'] as String,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(bottom: last ? 0 : 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsetsDirectional.only(top: 2),
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(_icon(category), size: 18, color: fg),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: AppText.bodyMd.copyWith(color: AppColors.text),
                        children: [
                          TextSpan(
                            text: name,
                            style: AppText.titleMd.copyWith(
                              color: AppColors.text,
                            ),
                          ),
                          TextSpan(
                            text:
                                ' ${eventAction(l, event).toLowerCase()} ${event['title']}',
                          ),
                        ],
                      ),
                    ),
                    if (when != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 2),
                        child: Text(
                          relativeTime(l, when.toLocal()),
                          style: AppText.labelSm.copyWith(
                            color: AppColors.muted,
                            letterSpacing: 0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(String category) => switch (category) {
    'shopping' => Icons.add_shopping_cart,
    'repairs' => Icons.construction,
    'inventory' => Icons.inventory_2_outlined,
    'members' || 'household' => Icons.group_outlined,
    'chat' => Icons.chat_bubble_outline,
    _ => Icons.check_circle_outline,
  };
}
