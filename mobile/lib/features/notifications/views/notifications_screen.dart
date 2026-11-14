import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../dashboard/widgets/hub_widgets.dart';
import '../../tasks/widgets/task_widgets.dart';
import '../services/push_service.dart';
import '../viewmodels/notifications_viewmodel.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) unawaited(context.read<NotificationsViewModel>().open());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy, vm = context.watch<NotificationsViewModel>();
    String? lastDay;
    return AppScaffold(
      title: l.hubNotifications,
      actions: [
        IconButton(
          tooltip: l.hubNotifySettings,
          onPressed: () => context.pushNamed('notificationSettings'),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l.hubUnreadCount(vm.unread)),
                TextButton.icon(
                  onPressed: vm.busy || vm.loading
                      ? null
                      : () => vm.action(null, 'read'),
                  icon: const Icon(Icons.done_all),
                  label: Text(l.hubReadAll),
                ),
                FilterChip(
                  label: Text(l.hubUnread),
                  selected: vm.unreadOnly,
                  onSelected: vm.loading ? null : vm.filter,
                ),
              ],
            ),
            HubStatus(vm),
            if (vm.permission == PushPermission.denied) Text(l.hubPushDenied),
            if (!vm.loading && vm.items.isEmpty && vm.error == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.done_all,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      Text(
                        vm.unreadOnly ? l.hubNoUnread : l.hubCaughtUp,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(l.hubCaughtUpBody, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            for (final notification in vm.items) ...[
              if (lastDay !=
                  section(context, notification['created_at'] as String))
                Padding(
                  padding: const EdgeInsets.only(top: 18, bottom: 8),
                  child: Text(
                    lastDay = section(
                      context,
                      notification['created_at'] as String,
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              Card(
                color: notification['read_at'] == null
                    ? AppColors.lightBlue
                    : Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    child: Icon(
                      hubIcon(notification['related_entity_type'] as String),
                    ),
                  ),
                  title: Text(
                    notification['title'] as String,
                    style: TextStyle(
                      fontWeight: notification['read_at'] == null
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    '${notification['body']}\n${taskTimestamp(context, notification['created_at'])}',
                  ),
                  onTap: () {
                    vm.pendingId = notification['id'] as String;
                    vm.pendingUser = vm.user;
                    vm.checkSession();
                  },
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) =>
                        vm.action(notification['id'] as String, action),
                    itemBuilder: (_) => [
                      if (notification['read_at'] == null)
                        PopupMenuItem(value: 'read', child: Text(l.hubRead)),
                      PopupMenuItem(
                        value: 'dismiss',
                        child: Text(l.hubDismiss),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (vm.error != null && !vm.loading)
              TextButton(onPressed: vm.load, child: Text(l.retry)),
            if (vm.more)
              TextButton(
                onPressed: vm.loading ? null : () => vm.page(next: true),
                child: Text(l.taskLoadMore),
              ),
          ],
        ),
      ),
    );
  }

  String section(BuildContext context, String stamp) {
    final l = context.taskCopy, day = hubDay(context, DateTime.parse(stamp));
    return day == l.hubToday || day == l.hubYesterday ? day : l.hubEarlier;
  }
}
