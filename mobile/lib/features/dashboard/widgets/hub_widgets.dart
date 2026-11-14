import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../notifications/viewmodels/notifications_viewmodel.dart';
import '../../tasks/widgets/task_widgets.dart';
import '../viewmodels/scoped_hub_model.dart';

String hubError(BuildContext context, String? code) {
  final l = context.taskCopy;
  return switch (code) {
    'not_found' || 'forbidden' || 'unauthorized' => l.hubUnavailable,
    'network' => l.taskNetworkError,
    'push_registration' => l.hubPushRegistration,
    _ => l.hubLoadFailed,
  };
}

String hubDay(BuildContext context, DateTime value) {
  final l = context.taskCopy,
      now = DateUtils.dateOnly(DateTime.now()),
      day = DateUtils.dateOnly(value.toLocal());
  if (day == now) return l.hubToday;
  if (day == now.subtract(const Duration(days: 1))) return l.hubYesterday;
  return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
      .format(day);
}

IconData hubIcon(String type) => switch (type) {
  'inventory' => Icons.inventory_2_outlined,
  'shopping' => Icons.shopping_bag_outlined,
  'repairs' => Icons.build_outlined,
  'members' || 'household' => Icons.group_outlined,
  'chat' => Icons.chat_bubble_outline,
  _ => Icons.checklist,
};
Color hubColor(String type) => switch (type) {
  'inventory' => const Color(0xFF98601D),
  'shopping' => const Color(0xFF00714D),
  'repairs' => AppColors.danger,
  _ => AppColors.primary,
};

String eventAction(AppLocalizations l, Map<String, dynamic> row) =>
    switch (row['event_type']) {
      'created' => l.hubCreated,
      'completed' =>
        row['category'] == 'shopping' ? l.hubPurchased : l.hubCompleted,
      'archived' => l.hubArchived,
      'restored' => l.hubRestored,
      'assigned' || 'claimed' || 'unassigned' => l.hubAssigned,
      'reopened' => l.hubReopened,
      'cancelled' => l.hubCancelled,
      'member_joined' => l.hubJoined,
      'member_left' => l.hubLeft,
      'member_added' => l.hubMemberAdded,
      'member_removed' => l.hubMemberRemoved,
      'member_role_changed' => l.hubRole,
      'quantity_changed' => l.hubStock,
      'condition_changed' => l.hubCondition,
      'comment_added' || 'comment_edited' || 'comment_deleted' => l.hubComment,
      'attachment_added' ||
      'attachment_removed' ||
      'photo_changed' => l.hubPhoto,
      _ => l.hubUpdatedAction,
    };

class HubStatus extends StatelessWidget {
  const HubStatus(this.model, {super.key});
  final ScopedHubModel model;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (model.loading) const LinearProgressIndicator(),
        if (model.cached)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l.hubCached),
          ),
        if (model.cacheError) Text(l.chatCacheError),
        if (model.savedAt != null)
          Text(
            l.hubUpdated(
              DateFormat.yMMMd().add_jm().format(model.savedAt!.toLocal()),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (model.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(hubError(context, model.error)),
          ),
      ],
    );
  }
}

Future<void> openHubEntity(
  BuildContext context,
  String type,
  String id,
  String home,
) async {
  final vm = context.read<NotificationsViewModel>();
  final target = await vm.resolveEntity(type, id, home);
  if (!context.mounted) return;
  if (target == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.taskCopy.hubUnavailable)));
    return;
  }
  context.pushNamed(
    target.route,
    pathParameters: {if (target.id != null) 'id': target.id!},
  );
}

class FamilyEventTile extends StatelessWidget {
  const FamilyEventTile(this.event, {super.key});
  final Map<String, dynamic> event;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy,
        actor = event['actor_display_name'] as String?,
        color = hubColor(event['category'] as String);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(hubIcon(event['category'] as String), color: color),
          ),
          title: Text(event['title'] as String),
          subtitle: Text(
            '${l.hubActivityDetail(actor == null || actor.isEmpty ? l.hubFormer : actor, eventAction(l, event))}\n${taskTimestamp(context, event['created_at'])}',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openHubEntity(
            context,
            event['entity_type'] as String,
            event['entity_id'] as String,
            event['household_id'] as String,
          ),
        ),
      ),
    );
  }
}

class HubRecordCard extends StatelessWidget {
  const HubRecordCard(this.record, {super.key});
  final Map<String, dynamic> record;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy,
        type =
            record['task_type'] as String? ?? record['entity_type'] as String,
        status = record['status'] as String;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: hubColor(type).withValues(alpha: .12),
          child: Icon(
            hubIcon(type == 'repair' ? 'repairs' : type),
            color: hubColor(type),
          ),
        ),
        title: Text(
          record['title'] as String,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            if (record['priority'] != null)
              taskLabel(context, record['priority'] as String),
            status == 'out_of_stock'
                ? l.hubOutStock
                : status == 'low_stock'
                ? l.hubLowStock
                : status == 'broken'
                ? l.hubBroken
                : status == 'needs_repair'
                ? l.hubNeedsRepair
                : taskLabel(context, status),
            if (record['assignee_name'] != null)
              record['assignee_name'] as String,
            if (record['due_date'] != null) record['due_date'] as String,
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openHubEntity(
          context,
          record['entity_type'] as String,
          record['id'] as String,
          record['household_id'] as String,
        ),
      ),
    );
  }
}
