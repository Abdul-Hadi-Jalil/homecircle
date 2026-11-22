import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/mock_widgets.dart';
import '../../dashboard/widgets/hub_widgets.dart';
import '../../tasks/widgets/task_widgets.dart';
import '../viewmodels/activity_viewmodel.dart';

/// "Family Activity History" (UI/family_activity_history).
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
    // Group the loaded events by day label, keeping order.
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final event in vm.items) {
      final day = hubDay(
        context,
        DateTime.parse(event['created_at'] as String),
      );
      groups.putIfAbsent(day, () => []).add(event);
    }
    return AppScaffold(
      title: l.familyActivity,
      appBar: BrandAppBar(
        title: l.familyActivity,
        onBack: () =>
            context.canPop() ? context.pop() : context.goNamed('home'),
        onProfile: () => context.goNamed('profile'),
        actions: [
          IconButton(
            tooltip: l.hubDateRange,
            onPressed: dates,
            icon: const Icon(Icons.date_range, color: AppColors.text),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
          children: [
            Text(
              l.hubActivitySubtitle,
              style: AppText.bodyMd.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final entry in [
                    ('all', l.hubAll),
                    ('inventory', l.hubInventory),
                    ('shopping', l.shopping),
                    ('tasks', l.hubTasks),
                    ('repairs', l.hubRepairs),
                    ('members', l.hubMembers),
                  ])
                    _FilterChip(
                      label: entry.$2,
                      count: vm.category == entry.$1 && entry.$1 == 'all'
                          ? vm.items.length
                          : null,
                      selected: vm.category == entry.$1,
                      onTap: () => vm.filter(entry.$1),
                    ),
                ],
              ),
            ),
            if (vm.start != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => vm.dateRange(null, null),
                  child: Text(l.hubClearDates),
                ),
              ),
            const SizedBox(height: 8),
            if (vm.loading) const LinearProgressIndicator(minHeight: 2),
            if (vm.cached)
              Text(
                l.hubCached,
                style: AppText.bodySm.copyWith(color: AppColors.muted),
              ),
            if (!vm.loading && vm.items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  vm.error == null
                      ? l.hubNoActivity
                      : hubError(context, vm.error),
                  textAlign: TextAlign.center,
                  style: AppText.bodyMd.copyWith(color: AppColors.muted),
                ),
              ),
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 56,
                  top: 16,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.key,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.headlineSm.copyWith(
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox.square(
                      dimension: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: entry.key == l.hubToday
                              ? AppColors.primary
                              : AppColors.surfaceHighest,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l.hubUpdatesCount(entry.value.length),
                        overflow: TextOverflow.ellipsis,
                        style: AppText.labelMd.copyWith(
                          color: AppColors.muted,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < entry.value.length; i++)
                _TimelineEvent(
                  event: entry.value[i],
                  last:
                      i == entry.value.length - 1 &&
                      entry.key == groups.keys.last,
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
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: Material(
      color: selected ? AppColors.primary : AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                label,
                style: AppText.labelLg.copyWith(
                  color: selected ? Colors.white : AppColors.text,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(60),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    '$count',
                    style: AppText.labelSm.copyWith(
                      color: Colors.white,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _TimelineEvent extends StatelessWidget {
  const _TimelineEvent({required this.event, required this.last});
  final Map<String, dynamic> event;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final category = event['category'] as String;
    final actor = (event['actor_display_name'] as String?)?.trim();
    final name = actor == null || actor.isEmpty ? l.hubFormer : actor;
    final (avBg, avFg) = taskAvatarColors(name);
    final when = DateTime.parse(event['created_at'] as String).toLocal();
    final (tileBg, tileFg, icon) = switch (category) {
      'inventory' => (
        AppColors.tertiaryFixed,
        AppColors.tertiary,
        Icons.inventory_2_outlined,
      ),
      'repairs' => (
        const Color(0xFFFFDAD6),
        AppColors.danger,
        Icons.build_outlined,
      ),
      'shopping' => (
        AppColors.primaryFixed,
        AppColors.primary,
        Icons.shopping_cart_outlined,
      ),
      'members' ||
      'household' => (AppColors.primary, Colors.white, Icons.person_add_alt),
      _ => (
        AppColors.secondaryContainer,
        AppColors.secondary,
        Icons.check_circle_outline,
      ),
    };
    final meta = event['metadata'];
    final priority = meta is Map ? meta['priority'] as String? : null;
    final status = meta is Map ? meta['status'] as String? : null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tileBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: tileFg),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: AppColors.surfaceHigh),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => openHubEntity(
                    context,
                    event['entity_type'] as String,
                    event['entity_id'] as String,
                    event['household_id'] as String,
                  ),
                  child: Ink(
                    padding: const EdgeInsetsDirectional.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppShadows.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  InitialsAvatar(
                                    name,
                                    size: 24,
                                    bg: avBg,
                                    fg: avFg,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.labelMd.copyWith(
                                        color: AppColors.text,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    DateFormat.jm().format(when),
                                    style: AppText.labelMd.copyWith(
                                      color: AppColors.muted,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${eventAction(l, event)} ${event['title']}',
                                style: AppText.bodyLg.copyWith(
                                  color: AppColors.text,
                                ),
                              ),
                              if (priority != null || status != null)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    top: 8,
                                  ),
                                  child: Wrap(
                                    spacing: 6,
                                    children: [
                                      if (priority != null)
                                        AppPill(
                                          taskLabel(context, priority),
                                          bg: priority == 'urgent'
                                              ? const Color(0xFFFFDAD6)
                                              : AppColors.primaryFixed,
                                          fg: priority == 'urgent'
                                              ? AppColors.danger
                                              : AppColors.primary,
                                        ),
                                      if (status != null)
                                        AppPill(
                                          taskLabel(context, status),
                                          bg: AppColors.surfaceContainer,
                                          fg: AppColors.muted,
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 22,
                          color: Color(0xFF747686),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
