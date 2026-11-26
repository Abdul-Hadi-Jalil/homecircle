import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/mock_widgets.dart';
import '../models/household_task.dart';
import '../viewmodels/tasks_view_model.dart';
import '../widgets/task_filter_sheet.dart';
import '../widgets/task_widgets.dart';

const _outline = Color(0xFF747686);

/// "Tasks & Requests" tab (UI/tasks_requests_overview, UI/task_empty_state).
class TasksScreen extends StatefulWidget {
  const TasksScreen({this.linkedItemId, this.initialFilters, super.key});
  final String? linkedItemId;
  final Map<String, String>? initialFilters;
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final search = TextEditingController();
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final vm = context.read<TasksViewModel>();
      if (widget.initialFilters != null) {
        vm.filters = {...widget.initialFilters!};
      }
      if (widget.linkedItemId != null) {
        vm.filters = {
          'linked_inventory_item_id': widget.linkedItemId!,
          'task_type': 'repair',
        };
      }
      search.text = vm.filters['search'] ?? '';
      vm.load();
      vm.loadMembers();
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final vm = context.read<TasksViewModel>();
    await context.pushNamed('createTask');
    if (mounted) await vm.load();
  }

  void _type(TasksViewModel vm, String? type) {
    final next = {...vm.filters};
    if (type == null) {
      next.remove('task_type');
    } else {
      next['task_type'] = type;
    }
    vm.filters = next;
    vm.load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final vm = context.watch<TasksViewModel>();
    final filtered = vm.filters.isNotEmpty;
    final type = vm.filters['task_type'];
    final mine = vm.filters['assignment'] == 'me';
    final sort = vm.filters['sort'] ?? 'priority';
    return AppScaffold(
      title: l.taskScreenTitle,
      appBar: BrandAppBar(
        title: l.appName,
        onProfile: () => context.goNamed('profile'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        tooltip: l.taskNewTask,
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      body: RefreshIndicator(
        onRefresh: () => vm.load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 96),
          children: [
            if (vm.listCached)
              _OfflineBanner(
                l: l,
                onRetry: vm.listLoading ? null : () => vm.load(),
              ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.taskScreenTitle,
                        style: AppText.headlineLg.copyWith(
                          color: AppColors.text,
                          letterSpacing: -0.65,
                        ),
                      ),
                      Text(
                        l.taskScreenSubtitle,
                        style: AppText.bodySm.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 116,
                  child: AppCta(
                    label: l.taskNewTask,
                    icon: Icons.add,
                    onPressed: _create,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final entry in [
                  ('open', AppColors.primaryFixed, AppColors.primary),
                  ('in_progress', AppColors.tertiaryFixed, AppColors.tertiary),
                  (
                    'completed',
                    AppColors.secondaryContainer,
                    AppColors.secondary,
                  ),
                ]) ...[
                  if (entry.$1 != 'open') const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      count: vm.summary[entry.$1],
                      label: taskLabel(context, entry.$1),
                      bg: entry.$2,
                      fg: entry.$3,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.sm,
              ),
              child: TextField(
                controller: search,
                style: AppText.bodyMd.copyWith(color: AppColors.text),
                decoration: InputDecoration(
                  hintText: l.taskSearch,
                  hintStyle: AppText.bodyMd.copyWith(color: _outline),
                  prefixIcon: const Icon(Icons.search, color: _outline),
                  suffixIcon: IconButton(
                    tooltip: l.taskFilters,
                    icon: const Icon(Icons.tune, size: 20, color: _outline),
                    onPressed: () async {
                      final result =
                          await showModalBottomSheet<Map<String, String>>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => TaskFilterSheet(
                              initial: vm.filters,
                              members: vm.members,
                            ),
                          );
                      if (result != null && mounted) {
                        vm.filters = result;
                        search.text = result['search'] ?? '';
                        await vm.load();
                      }
                    },
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsetsDirectional.symmetric(
                    vertical: 16,
                  ),
                ),
                onChanged: (v) {
                  debounce?.cancel();
                  debounce = Timer(const Duration(milliseconds: 350), () {
                    if (mounted) {
                      vm.filters = {...vm.filters, 'search': v.trim()};
                      vm.load();
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _TypeChip(
                    label: l.taskAllTypes,
                    selected: type == null,
                    onTap: () => _type(vm, null),
                  ),
                  _TypeChip(
                    label: l.taskShoppingSoon,
                    selected: type == 'shopping',
                    onTap: () => _type(vm, 'shopping'),
                  ),
                  _TypeChip(
                    label: l.taskKindRepairs,
                    selected: type == 'repair',
                    onTap: () => _type(vm, 'repair'),
                  ),
                  _TypeChip(
                    label: l.taskKindChores,
                    selected: type == 'chore',
                    onTap: () => _type(vm, 'chore'),
                  ),
                  _TypeChip(
                    label: l.taskGeneral,
                    selected: type == 'general',
                    onTap: () => _type(vm, 'general'),
                  ),
                  _TypeChip(
                    label: l.taskArchived,
                    selected: vm.archived,
                    onTap: () {
                      vm.filters = {
                        ...vm.filters,
                        'archived': '${!vm.archived}',
                      };
                      vm.load();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsetsDirectional.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: _Segment(
                            label: l.taskAllTasks,
                            selected: !mine,
                            onTap: () {
                              vm.filters = {...vm.filters, 'assignment': 'all'}
                                ..remove('assigned_to');
                              vm.load();
                            },
                          ),
                        ),
                        Flexible(
                          child: _Segment(
                            label: l.taskAssignedToMe,
                            selected: mine,
                            onTap: () {
                              vm.filters = {...vm.filters, 'assignment': 'me'}
                                ..remove('assigned_to');
                              vm.load();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: PopupMenuButton<String>(
                    tooltip: l.taskSortBy,
                    onSelected: (value) {
                      vm.filters = {...vm.filters, 'sort': value};
                      vm.load();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'priority',
                        child: Text(l.taskSortPriority),
                      ),
                      PopupMenuItem(
                        value: 'due_date',
                        child: Text(l.taskSortDue),
                      ),
                      PopupMenuItem(
                        value: 'updated',
                        child: Text(l.taskSortUpdated),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.tune,
                            size: 18,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              switch (sort) {
                                'due_date' => l.taskSortDue,
                                'updated' => l.taskSortUpdated,
                                _ => l.taskSortPriority,
                              },
                              style: AppText.labelMd.copyWith(
                                color: AppColors.text,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (vm.errorCode != null)
              _ErrorRow(
                text:
                    '${l.taskCouldntRefresh} • ${taskError(context, vm.errorCode)}',
                retry: l.retry,
                onRetry: vm.listLoading ? null : () => vm.load(),
              ),
            if (vm.listLoading) const LinearProgressIndicator(minHeight: 2),
            if (!vm.listLoading && vm.items.isEmpty && vm.errorCode == null)
              filtered
                  ? _FilteredEmpty(
                      l: l,
                      onClear: () {
                        vm.filters = {};
                        search.clear();
                        vm.load();
                      },
                    )
                  : _AllClear(l: l, onCreate: _create),
            for (final task in vm.items)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 12),
                child: TaskCard(
                  task: task,
                  onTap: () async {
                    await context.pushNamed(
                      task.kind == TaskKind.shopping
                          ? 'shoppingDetails'
                          : 'taskDetails',
                      pathParameters: {'id': task.id},
                    );
                    if (mounted) await vm.load();
                  },
                ),
              ),
            if (vm.items.length < vm.total)
              TextButton(
                onPressed: vm.listLoading
                    ? null
                    : () => vm.load(nextPage: true),
                child: Text(
                  l.taskLoadMore,
                  style: AppText.labelLg.copyWith(color: AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.l, required this.onRetry});
  final AppLocalizations l;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsetsDirectional.only(top: 8),
    padding: const EdgeInsetsDirectional.all(12),
    decoration: BoxDecoration(
      color: AppColors.primaryFixed.withAlpha(150),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFFFDAD6),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.wifi_off, size: 20, color: AppColors.danger),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            l.taskOfflineTitle,
            style: AppText.labelMd.copyWith(
              color: AppColors.text,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9999),
          child: InkWell(
            borderRadius: BorderRadius.circular(9999),
            onTap: onRetry,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sync, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    l.retry,
                    style: AppText.labelMd.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.count,
    required this.label,
    required this.bg,
    required this.fg,
  });
  final dynamic count;
  final String label;
  final Color bg;
  final Color fg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(vertical: 12, horizontal: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppShadows.sm,
    ),
    child: Column(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Text(
            '${count ?? '–'}',
            style: AppText.headlineSm.copyWith(color: fg),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppText.labelMd.copyWith(
            color: AppColors.muted,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: Material(
      color: selected ? AppColors.primaryContainer : AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          child: Text(
            label,
            style: AppText.labelLg.copyWith(
              color: selected ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected ? AppShadows.sm : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.labelMd.copyWith(
            color: selected ? AppColors.primary : AppColors.muted,
            letterSpacing: 0,
          ),
        ),
      ),
    ),
  );
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({
    required this.text,
    required this.retry,
    required this.onRetry,
  });
  final String text;
  final String retry;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsetsDirectional.only(bottom: 12),
    padding: const EdgeInsetsDirectional.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFDAD6).withAlpha(150),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, size: 22, color: AppColors.danger),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodySm.copyWith(color: AppColors.text),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onRetry,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              child: Text(
                retry,
                style: AppText.labelMd.copyWith(color: AppColors.danger),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _AllClear extends StatelessWidget {
  const _AllClear({required this.l, required this.onCreate});
  final AppLocalizations l;
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 20,
    padding: const EdgeInsetsDirectional.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLow,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppShadows.md,
                ),
                child: const Icon(
                  Icons.checklist_rtl,
                  size: 40,
                  color: AppColors.primaryContainer,
                ),
              ),
              Positioned(
                top: 6,
                right: 62,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.tertiaryFixed,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.light_mode_outlined,
                    size: 24,
                    color: AppColors.tertiary,
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 62,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 22,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l.taskAllClear,
          textAlign: TextAlign.center,
          style: AppText.headlineMd.copyWith(color: AppColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          l.taskAllClearBody,
          textAlign: TextAlign.center,
          style: AppText.bodyLg.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        AppCta(
          label: l.taskCreateRequest,
          icon: Icons.add,
          color: AppColors.primary,
          onPressed: onCreate,
        ),
        const SizedBox(height: 16),
        Center(
          child: AppPill(
            l.taskCaughtUp,
            bg: AppColors.surfaceLow,
            fg: AppColors.text,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            style: AppText.labelMd.copyWith(letterSpacing: 0),
          ),
        ),
      ],
    ),
  );
}

class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({required this.l, required this.onClear});
  final AppLocalizations l;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 20,
    padding: const EdgeInsetsDirectional.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const IconTile(
              icon: Icons.filter_alt_off_outlined,
              bg: AppColors.surfaceContainer,
              fg: AppColors.muted,
              size: 44,
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.taskFilteredEmpty,
                    style: AppText.headlineSm.copyWith(color: AppColors.text),
                  ),
                  Text(
                    l.taskFilteredEmptyBody,
                    style: AppText.bodySm.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsetsDirectional.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.manage_search, size: 24, color: AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.taskCopy.taskNoResults,
                  style: AppText.bodyMd.copyWith(color: AppColors.text),
                ),
              ),
              TextButton(
                onPressed: onClear,
                child: Text(
                  context.taskCopy.taskClearFilters,
                  style: AppText.labelMd.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
