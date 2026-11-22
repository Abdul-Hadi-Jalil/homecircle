import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/mock_widgets.dart';
import '../../../core/widgets/quick_actions_sheet.dart';
import '../../household/viewmodels/session_view_model.dart';
import '../../inventory/viewmodels/inventory_view_model.dart';
import '../../tasks/viewmodels/tasks_view_model.dart';
import '../../tasks/widgets/task_widgets.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../widgets/hub_cards.dart';
import '../widgets/hub_widgets.dart';

const _outline = Color(0xFF747686);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted) unawaited(context.read<DashboardViewModel>().open());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(context.read<DashboardViewModel>().load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void tasks({bool urgent = false}) {
    context.read<TasksViewModel>().filters = {
      'active_only': 'true',
      'exclude_shopping': 'true',
      if (urgent) 'priority': 'urgent',
    };
    context.goNamed(
      'tasks',
      queryParameters: {'active': 'true', if (urgent) 'priority': 'urgent'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final vm = context.watch<DashboardViewModel>();
    final session = context.watch<SessionViewModel>();
    final data = vm.snapshot;
    final name = (session.profile?['display_name'] as String?)?.trim();
    final member = name == null || name.isEmpty ? l.hubMember : name;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? l.hubMorning(member)
        : hour < 18
        ? l.hubAfternoon(member)
        : l.hubEvening(member);
    final unread = data?.data['unread_notifications'] as int? ?? 0;
    final attention = data?.rows('needs_attention') ?? const [];
    final high = attention
        .where((r) => r['priority'] == 'urgent' || r['priority'] == 'high')
        .length;
    return AppScaffold(
      title: l.appName,
      appBar: BrandAppBar(
        title: l.appName,
        onProfile: () => context.goNamed('profile'),
      ),
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.headlineMd.copyWith(
                          color: AppColors.text,
                          letterSpacing: -0.2,
                        ),
                      ),
                      InkWell(
                        onTap: () => context.goNamed('selectHousehold'),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: _outline,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  session.activeHousehold?.name ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.bodySm.copyWith(
                                    color: AppColors.muted,
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
                const SizedBox(width: 8),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Material(
                      color: AppColors.surfaceLow,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => context.pushNamed('notifications'),
                        child: Tooltip(
                          message: l.hubNotifications,
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.notifications_outlined,
                              size: 22,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (unread > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.background,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.goNamed('profile'),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.sm,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                    child: InitialsAvatar(
                      member,
                      size: 36,
                      bg: AppColors.tertiaryFixed,
                      fg: AppColors.onTertiaryFixed,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (vm.loading) const LinearProgressIndicator(minHeight: 2),
            if (vm.cached)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Text(
                  l.hubCached,
                  style: AppText.bodySm.copyWith(color: AppColors.muted),
                ),
              ),
            if (vm.error != null && !vm.loading)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hubError(context, vm.error),
                        style: AppText.bodySm.copyWith(color: AppColors.danger),
                      ),
                    ),
                    TextButton(onPressed: vm.load, child: Text(l.retry)),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            _Glance(data: data, vm: vm, tasks: tasks, l: l),
            const SizedBox(height: 24),
            _SectionHeader(
              title: l.hubQuick,
              trailing: InkWell(
                onTap: () => showQuickActionsSheet(
                  context,
                  householdName: session.activeHousehold?.name ?? '',
                ),
                child: Text(
                  l.hubFrequent,
                  style: AppText.labelSm.copyWith(
                    color: _outline,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, box) {
                final w = (box.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickAction(
                      width: w,
                      icon: Icons.add_box_outlined,
                      bg: AppColors.surfaceContainer,
                      fg: AppColors.primary,
                      title: l.hubAddItem,
                      subtitle: l.hubAddItemSub,
                      onTap: () => context.pushNamed('addInventory'),
                    ),
                    _QuickAction(
                      width: w,
                      icon: Icons.volunteer_activism_outlined,
                      bg: AppColors.primaryFixed,
                      fg: AppColors.primary,
                      title: l.hubRequest,
                      subtitle: l.hubRequestSub,
                      onTap: () => context.pushNamed('createTask'),
                    ),
                    _QuickAction(
                      width: w,
                      icon: Icons.build_outlined,
                      bg: const Color(0x99FFDDB5),
                      fg: AppColors.tertiary,
                      title: l.hubReport,
                      subtitle: l.hubReportSub,
                      onTap: () => context.pushNamed(
                        'createTask',
                        queryParameters: {'type': 'repair'},
                      ),
                    ),
                    _QuickAction(
                      width: w,
                      icon: Icons.forum_outlined,
                      bg: const Color(0x8082F9C1),
                      fg: AppColors.secondary,
                      title: l.hubMessage,
                      subtitle: l.hubMessageSub,
                      onTap: () => context.goNamed('chat'),
                    ),
                  ],
                );
              },
            ),
            if (data?.empty == true) ...[
              const SizedBox(height: 24),
              _EmptyHome(l: l, admin: session.activeHousehold?.role == 'admin'),
            ],
            if (data != null && !data.empty) ...[
              const SizedBox(height: 24),
              _SectionHeader(
                title: l.hubAttention,
                badge: high > 0 ? l.hubHighCount(high) : null,
                action: l.hubViewAll,
                onAction: () => tasks(),
              ),
              const SizedBox(height: 8),
              if (attention.isEmpty)
                Text(
                  l.hubNoAttention,
                  style: AppText.bodyMd.copyWith(color: AppColors.muted),
                ),
              for (final record in attention)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 8),
                  child: HubRecordCard(record),
                ),
              const SizedBox(height: 16),
              _SectionHeader(
                title: l.hubUpcoming,
                action: l.hubViewAll,
                onAction: () => context.goNamed('tasks'),
              ),
              const SizedBox(height: 8),
              if (data.rows('upcoming_tasks').isEmpty)
                Text(
                  l.hubNoUpcoming,
                  style: AppText.bodyMd.copyWith(color: AppColors.muted),
                ),
              for (final record in data.rows('upcoming_tasks'))
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 8),
                  child: HubRecordCard(record),
                ),
            ],
            const SizedBox(height: 24),
            _SectionHeader(
              title: l.hubRecent,
              action: l.hubHistory,
              onAction: () => context.pushNamed('familyActivity'),
            ),
            const SizedBox(height: 8),
            if (data != null && data.rows('recent_activity').isEmpty)
              Text(
                l.hubNoActivity,
                style: AppText.bodyMd.copyWith(color: AppColors.muted),
              ),
            if (data != null && data.rows('recent_activity').isNotEmpty)
              ActivityTimeline(data.rows('recent_activity')),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.badge,
    this.action,
    this.onAction,
    this.trailing,
  });
  final String title;
  final String? badge;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: AppText.headlineSm.copyWith(color: AppColors.text),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              AppPill(
                badge!,
                bg: const Color(0xFFFFDAD6),
                fg: AppColors.danger,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
              ),
            ],
          ],
        ),
      ),
      ?trailing,
      if (action != null)
        InkWell(
          onTap: onAction,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
            child: Text(
              action!,
              style: AppText.labelLg.copyWith(color: AppColors.primary),
            ),
          ),
        ),
    ],
  );
}

class _Glance extends StatelessWidget {
  const _Glance({
    required this.data,
    required this.vm,
    required this.tasks,
    required this.l,
  });
  final dynamic data;
  final DashboardViewModel vm;
  final void Function({bool urgent}) tasks;
  final AppLocalizations l;
  @override
  Widget build(BuildContext context) {
    final saved = vm.savedAt;
    final lower = saved == null ? null : compactAgo(l, saved.toLocal());
    return AppCard(
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.hubGlance,
                      style: AppText.titleMd.copyWith(color: AppColors.text),
                    ),
                    Text(
                      l.hubGlanceSub,
                      style: AppText.labelSm.copyWith(
                        color: AppColors.muted,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (lower != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox.square(
                          dimension: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            l.hubUpdatedAgo(lower),
                            overflow: TextOverflow.ellipsis,
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
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final w = (box.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Stat(
                    width: w,
                    icon: Icons.checklist,
                    count: data?.count('pending_tasks') as int?,
                    label: l.hubPending,
                    bg: AppColors.surfaceLow,
                    iconBg: AppColors.primaryFixed,
                    fg: AppColors.primary,
                    numberColor: AppColors.text,
                    labelColor: AppColors.muted,
                    onTap: () => tasks(),
                  ),
                  _Stat(
                    width: w,
                    icon: Icons.warning,
                    count: data?.count('urgent_issues') as int?,
                    label: l.hubUrgent,
                    bg: const Color(0x4DFFDAD6),
                    iconBg: const Color(0xFFFFDAD6),
                    fg: AppColors.danger,
                    numberColor: AppColors.danger,
                    labelColor: AppColors.danger,
                    onTap: () => tasks(urgent: true),
                  ),
                  _Stat(
                    width: w,
                    icon: Icons.shopping_bag,
                    count: data?.count('shopping_items') as int?,
                    label: l.hubShoppingShort,
                    bg: const Color(0x4D82F9C1),
                    iconBg: AppColors.secondaryFixed,
                    fg: AppColors.secondary,
                    numberColor: AppColors.text,
                    labelColor: AppColors.onSecondaryContainer,
                    onTap: () => context.pushNamed('shopping'),
                  ),
                  _Stat(
                    width: w,
                    icon: Icons.inventory_2,
                    count: data?.count('low_stock_items') as int?,
                    label: l.hubLowStockShort,
                    bg: const Color(0x66FFDDB5),
                    iconBg: AppColors.tertiaryFixed,
                    fg: AppColors.tertiary,
                    numberColor: AppColors.text,
                    labelColor: AppColors.tertiary,
                    onTap: () {
                      context.read<InventoryViewModel>().filters = {
                        'stock_status': 'low_stock',
                      };
                      context.goNamed(
                        'inventory',
                        queryParameters: {'stock': 'low_stock'},
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.width,
    required this.icon,
    required this.count,
    required this.label,
    required this.bg,
    required this.iconBg,
    required this.fg,
    required this.numberColor,
    required this.labelColor,
    required this.onTap,
  });
  final double width;
  final IconData icon;
  final int? count;
  final String label;
  final Color bg;
  final Color iconBg;
  final Color fg;
  final Color numberColor;
  final Color labelColor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(8),
          child: Row(
            children: [
              IconTile(icon: icon, bg: iconBg, fg: fg, size: 40, radius: 8),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == null ? '–' : '$count',
                      style: AppText.headlineSm.copyWith(
                        color: numberColor,
                        height: 1.25,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 2,
                      style: AppText.labelSm.copyWith(
                        color: labelColor,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.width,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final double width;
  final IconData icon;
  final Color bg;
  final Color fg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsetsDirectional.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: icon, bg: bg, fg: fg, size: 44, iconSize: 24),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppText.labelLg.copyWith(color: AppColors.text),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppText.bodySm.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.l, required this.admin});
  final AppLocalizations l;
  final bool admin;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsetsDirectional.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          child: IconTile(
            icon: Icons.cottage,
            bg: AppColors.surfaceHigh,
            fg: AppColors.primaryContainer,
            size: 64,
            iconSize: 32,
            radius: 20,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l.hubEmptyTitle,
          textAlign: TextAlign.center,
          style: AppText.headlineSm.copyWith(color: AppColors.text),
        ),
        const SizedBox(height: 4),
        Text(
          l.hubEmptyBody,
          textAlign: TextAlign.center,
          style: AppText.bodyMd.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        AppCta(
          label: l.hubFirstItem,
          icon: Icons.add,
          onPressed: () => context.pushNamed('addInventory'),
        ),
        if (admin) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => context.pushNamed('inviteFamily'),
            child: Text(
              l.inviteFamily,
              style: AppText.labelLg.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ],
    ),
  );
}
