import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../household/viewmodels/session_view_model.dart';
import '../../inventory/viewmodels/inventory_view_model.dart';
import '../../tasks/viewmodels/tasks_view_model.dart';
import '../../tasks/widgets/task_widgets.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../widgets/hub_widgets.dart';

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
    final l = context.taskCopy,
        vm = context.watch<DashboardViewModel>(),
        session = context.watch<SessionViewModel>(),
        data = vm.snapshot;
    final name = (session.profile?['display_name'] as String?)?.trim();
    final member = name == null || name.isEmpty ? l.hubMember : name,
        hour = DateTime.now().hour;
    final greeting = hour < 12
        ? l.hubMorning(member)
        : hour < 18
        ? l.hubAfternoon(member)
        : l.hubEvening(member);
    return AppScaffold(
      title: l.appName,
      actions: [
        IconButton(
          tooltip: l.switchHousehold,
          onPressed: () => context.goNamed('selectHousehold'),
          icon: const Icon(Icons.swap_horiz),
        ),
        IconButton(
          tooltip: l.profile,
          onPressed: () => context.goNamed('profile'),
          icon: const Icon(Icons.account_circle_outlined),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(session.activeHousehold?.name ?? ''),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.hubNotifications,
                  onPressed: () => context.pushNamed('notifications'),
                  icon: Badge(
                    isLabelVisible:
                        (data?.data['unread_notifications'] as int? ?? 0) > 0,
                    label: Text('${data?.data['unread_notifications'] ?? 0}'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            HubStatus(vm),
            if (vm.error != null && !vm.loading)
              TextButton(onPressed: vm.load, child: Text(l.retry)),
            if (data != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.hubGlance,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, box) {
                          final width = (box.maxWidth - 10) / 2;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              summary(
                                width,
                                l.hubPending,
                                data.count('pending_tasks'),
                                Icons.checklist,
                                AppColors.primary,
                                () => tasks(),
                              ),
                              summary(
                                width,
                                l.hubUrgent,
                                data.count('urgent_issues'),
                                Icons.warning_amber,
                                AppColors.danger,
                                () => tasks(urgent: true),
                              ),
                              summary(
                                width,
                                l.hubShopping,
                                data.count('shopping_items'),
                                Icons.shopping_bag_outlined,
                                const Color(0xFF00714D),
                                () => context.pushNamed('shopping'),
                              ),
                              summary(
                                width,
                                l.hubLowStock,
                                data.count('low_stock_items'),
                                Icons.inventory_2_outlined,
                                const Color(0xFF98601D),
                                () {
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
                      const SizedBox(height: 8),
                      Text(
                        '${l.hubOverdue}: ${data.count('overdue_tasks')} · ${l.hubMine}: ${data.count('my_tasks')} · ${l.hubOutStock}: ${data.count('out_of_stock_items')}',
                      ),
                      Text(
                        l.hubZone(
                          (data.data['household'] as Map)['time_zone']
                              as String,
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(l.hubQuick, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, box) {
                final w = (box.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    quick(
                      w,
                      l.hubAddItem,
                      Icons.add_box_outlined,
                      () => context.pushNamed('addInventory'),
                    ),
                    quick(
                      w,
                      l.hubRequest,
                      Icons.volunteer_activism_outlined,
                      () => context.pushNamed('createTask'),
                    ),
                    quick(
                      w,
                      l.hubReport,
                      Icons.build_outlined,
                      () => context.pushNamed(
                        'createTask',
                        queryParameters: {'type': 'repair'},
                      ),
                    ),
                    quick(
                      w,
                      l.hubMessage,
                      Icons.chat_bubble_outline,
                      () => context.goNamed('chat'),
                    ),
                  ],
                );
              },
            ),
            if (data?.empty == true)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.home_outlined, size: 48),
                      Text(
                        l.hubEmptyTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(l.hubEmptyBody, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.pushNamed('addInventory'),
                        child: Text(l.hubFirstItem),
                      ),
                      if (session.activeHousehold?.role == 'admin')
                        TextButton(
                          onPressed: () => context.pushNamed('inviteFamily'),
                          child: Text(l.inviteFamily),
                        ),
                    ],
                  ),
                ),
              ),
            if (data != null && !data.empty) ...[
              heading(l.hubAttention, () => tasks()),
              if (data.rows('needs_attention').isEmpty) Text(l.hubNoAttention),
              for (final record in data.rows('needs_attention'))
                HubRecordCard(record),
              heading(l.hubUpcoming, () => context.goNamed('tasks')),
              if (data.rows('upcoming_tasks').isEmpty) Text(l.hubNoUpcoming),
              for (final record in data.rows('upcoming_tasks'))
                HubRecordCard(record),
            ],
            heading(l.hubRecent, () => context.pushNamed('familyActivity')),
            if (data != null && data.rows('recent_activity').isEmpty)
              Text(l.hubNoActivity),
            if (data != null)
              for (final event in data.rows('recent_activity'))
                FamilyEventTile(event),
            const SizedBox(height: 16),
            ListTile(
              title: Text(l.shopping),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('shopping'),
            ),
            ListTile(
              title: Text(l.familyActivity),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('familyActivity'),
            ),
            ListTile(
              title: Text(l.familyMembers),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('members'),
            ),
            if (session.activeHousehold?.role == 'admin')
              ListTile(
                title: Text(l.householdSettings),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed('householdSettings'),
              ),
          ],
        ),
      ),
    );
  }

  Widget heading(String label, VoidCallback all) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleLarge),
        ),
        TextButton(onPressed: all, child: Text(context.taskCopy.hubViewAll)),
      ],
    ),
  );
  Widget summary(
    double width,
    String label,
    int count,
    IconData icon,
    Color color,
    VoidCallback tap,
  ) => SizedBox(
    width: width,
    child: Material(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              Text('$count', style: Theme.of(context).textTheme.headlineSmall),
              Text(label),
            ],
          ),
        ),
      ),
    ),
  );
  Widget quick(double width, String label, IconData icon, VoidCallback tap) =>
      SizedBox(
        width: width,
        child: Card(
          child: InkWell(
            onTap: tap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 30, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
