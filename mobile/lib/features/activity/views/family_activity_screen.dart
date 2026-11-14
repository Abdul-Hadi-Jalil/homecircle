import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../dashboard/widgets/hub_widgets.dart';
import '../../tasks/widgets/task_widgets.dart';
import '../viewmodels/activity_viewmodel.dart';

class FamilyActivityScreen extends StatefulWidget {
  const FamilyActivityScreen({super.key});
  @override
  State<FamilyActivityScreen> createState() => _FamilyActivityScreenState();
}

class _FamilyActivityScreenState extends State<FamilyActivityScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) unawaited(context.read<ActivityViewModel>().open());
    });
  }

  Future<void> dates() async {
    final vm = context.read<ActivityViewModel>(),
        captured = vm.scope,
        now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: vm.start == null
          ? null
          : DateTimeRange(
              start: vm.start!,
              end: vm.end!.subtract(const Duration(days: 1)),
            ),
    );
    if (range != null && mounted && vm.current(captured)) {
      await vm.dateRange(
        range.start,
        DateTime(range.end.year, range.end.month, range.end.day + 1),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy, vm = context.watch<ActivityViewModel>();
    String? lastDay;
    return AppScaffold(
      title: l.familyActivity,
      actions: [
        IconButton(
          tooltip: l.hubDateRange,
          onPressed: dates,
          icon: const Icon(Icons.date_range),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            Text(l.hubActivitySubtitle),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in [
                    ('all', l.hubAll),
                    ('inventory', l.hubInventory),
                    ('shopping', l.shopping),
                    ('tasks', l.hubTasks),
                    ('repairs', l.hubRepairs),
                    ('members', l.hubMembers),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(entry.$2),
                        selected: vm.category == entry.$1,
                        onSelected: (_) => vm.filter(entry.$1),
                      ),
                    ),
                ],
              ),
            ),
            if (vm.start != null)
              TextButton(
                onPressed: () => vm.dateRange(null, null),
                child: Text(l.hubClearDates),
              ),
            const SizedBox(height: 12),
            HubStatus(vm),
            if (!vm.loading && vm.items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  vm.error == null
                      ? l.hubNoActivity
                      : hubError(context, vm.error),
                  textAlign: TextAlign.center,
                ),
              ),
            for (final event in vm.items) ...[
              if (lastDay !=
                  hubDay(
                    context,
                    DateTime.parse(event['created_at'] as String),
                  ))
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 8),
                  child: Text(
                    lastDay = hubDay(
                      context,
                      DateTime.parse(event['created_at'] as String),
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              FamilyEventTile(event),
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
}
