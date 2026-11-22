import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/mock_widgets.dart';
import '../../dashboard/widgets/hub_widgets.dart';
import '../../tasks/widgets/task_widgets.dart';
import '../services/push_service.dart';
import '../viewmodels/notifications_viewmodel.dart';

/// "Notifications Center" (UI/notifications_center).
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
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final n in vm.items) {
      groups
          .putIfAbsent(section(context, n['created_at'] as String), () => [])
          .add(n);
    }
    return AppScaffold(
      title: l.hubNotifications,
      appBar: BrandAppBar(
        title: l.hubNotifications,
        onBack: () =>
            context.canPop() ? context.pop() : context.goNamed('home'),
        onProfile: () => context.goNamed('profile'),
        actions: [
          IconButton(
            tooltip: l.hubNotifySettings,
            onPressed: () => context.pushNamed('notificationSettings'),
            icon: const Icon(Icons.settings_outlined, color: AppColors.text),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                if (vm.unread > 0)
                  AppPill(
                    l.hubNewCount(vm.unread),
                    bg: AppColors.primary,
                    fg: Colors.white,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    style: AppText.labelMd.copyWith(letterSpacing: 0),
                  )
                else
                  Text(
                    l.hubUnreadCount(vm.unread),
                    style: AppText.labelMd.copyWith(
                      color: AppColors.muted,
                      letterSpacing: 0,
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.hubStaySynced,
                    style: AppText.bodyMd.copyWith(color: AppColors.muted),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(9999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9999),
                    onTap: vm.busy || vm.loading
                        ? null
                        : () => vm.action(null, 'read'),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.done_all,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l.hubReadAll,
                            style: AppText.labelMd.copyWith(
                              color: AppColors.primary,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _Chip(
                    label: l.hubAllCount(
                      vm.unreadOnly ? vm.unread : vm.items.length,
                    ),
                    selected: !vm.unreadOnly,
                    onTap: vm.loading ? null : () => vm.filter(false),
                  ),
                  _Chip(
                    label: l.hubUnread,
                    selected: vm.unreadOnly,
                    onTap: vm.loading ? null : () => vm.filter(true),
                  ),
                ],
              ),
            ),
            HubStatus(vm),
            if (vm.permission == PushPermission.denied)
              Text(
                l.hubPushDenied,
                style: AppText.bodySm.copyWith(color: AppColors.muted),
              ),
            if (!vm.loading && vm.items.isEmpty && vm.error == null)
              AppCard(
                radius: 16,
                padding: const EdgeInsetsDirectional.all(28),
                child: Column(
                  children: [
                    const IconTile(
                      icon: Icons.done_all,
                      bg: AppColors.surfaceContainer,
                      fg: AppColors.primary,
                      size: 64,
                      iconSize: 32,
                      radius: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      vm.unreadOnly ? l.hubNoUnread : l.hubCaughtUp,
                      style: AppText.headlineMd.copyWith(color: AppColors.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.hubCaughtUpBody,
                      textAlign: TextAlign.center,
                      style: AppText.bodyMd.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 16, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: AppText.headlineMd.copyWith(color: AppColors.text),
                    ),
                    Text(
                      l.hubUpdatesCount(entry.value.length),
                      style: AppText.labelMd.copyWith(
                        color: AppColors.muted,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              for (final n in entry.value)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 12),
                  child: _NotificationCard(
                    notification: n,
                    l: l,
                    onOpen: () {
                      vm.pendingId = n['id'] as String;
                      vm.pendingUser = vm.user;
                      vm.checkSession();
                    },
                    onAction: (action) => vm.action(n['id'] as String, action),
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
            if (vm.items.isNotEmpty && !vm.more && vm.unread == 0) ...[
              const SizedBox(height: 12),
              AppCard(
                color: AppColors.surfaceContainer.withAlpha(150),
                shadow: false,
                radius: 24,
                padding: const EdgeInsetsDirectional.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppPill(
                      l.hubPeace,
                      icon: Icons.self_improvement,
                      bg: AppColors.secondaryContainer,
                      fg: AppColors.onSecondaryContainer,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.hubCaughtUp,
                      style: AppText.headlineMd.copyWith(color: AppColors.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.hubCaughtUpBody,
                      style: AppText.bodyMd.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        8,
                        8,
                        8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.hubOlderArchives,
                              style: AppText.labelMd.copyWith(
                                color: AppColors.text,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                context.pushNamed('familyActivity'),
                            icon: const Icon(Icons.history, size: 18),
                            iconAlignment: IconAlignment.end,
                            label: Text(
                              l.hubHistoryArchive,
                              style: AppText.labelMd.copyWith(
                                color: AppColors.primary,
                                letterSpacing: 0,
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

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(9999),
            boxShadow: selected ? null : AppShadows.sm,
          ),
          child: Text(
            label,
            style: AppText.labelLg.copyWith(
              color: selected ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    ),
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.l,
    required this.onOpen,
    required this.onAction,
  });
  final Map<String, dynamic> notification;
  final AppLocalizations l;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) {
    final unread = notification['read_at'] == null;
    final entity = notification['related_entity_type'] as String;
    final when = DateTime.parse(notification['created_at'] as String).toLocal();
    final (tileBg, tileFg) = switch (entity) {
      'task' => (const Color(0xFFFFDAD6), AppColors.danger),
      'shopping' => (AppColors.tertiaryFixed, AppColors.tertiary),
      'inventory' => (AppColors.tertiaryFixed, AppColors.tertiary),
      'chat' => (AppColors.surfaceContainer, AppColors.primary),
      _ => (AppColors.secondaryContainer, AppColors.secondary),
    };
    final action = switch (entity) {
      'task' => l.hubViewTask,
      'shopping' => l.hubViewShopping,
      'inventory' => l.hubViewItem,
      'chat' => l.hubOpenChat,
      _ => l.hubViewDetails,
    };
    return Material(
      color: unread ? AppColors.surfaceContainer.withAlpha(170) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(
                color: unread ? AppColors.primary : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          padding: const EdgeInsetsDirectional.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                icon: hubIcon(entity),
                bg: tileBg,
                fg: tileFg,
                size: 48,
                iconSize: 24,
                radius: 14,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (unread) ...[
                          const SizedBox.square(
                            dimension: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            notification['title'] as String,
                            style: AppText.titleMd.copyWith(
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        Text(
                          compactAgo(l, when),
                          style: AppText.labelMd.copyWith(
                            color: AppColors.muted,
                            letterSpacing: 0,
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: l.taskMoreOptions,
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          icon: const Icon(
                            Icons.more_vert,
                            size: 18,
                            color: AppColors.muted,
                          ),
                          onSelected: onAction,
                          itemBuilder: (_) => [
                            if (unread)
                              PopupMenuItem(
                                value: 'read',
                                child: Text(l.hubRead),
                              ),
                            PopupMenuItem(
                              value: 'dismiss',
                              child: Text(l.hubDismiss),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['body'] as String,
                      style: AppText.bodyMd.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            action,
                            style: AppText.labelLg.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: AppColors.primary,
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
