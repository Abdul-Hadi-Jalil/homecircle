import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../models/household_task.dart';
import '../viewmodels/tasks_view_model.dart';
import '../widgets/task_widgets.dart';
import '../widgets/task_filter_sheet.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({this.linkedItemId, super.key});
  final String? linkedItemId;
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

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy, vm = context.watch<TasksViewModel>();
    return AppScaffold(
      title: l.taskScreenTitle,
      actions: [
        IconButton(
          tooltip: l.taskRefresh,
          onPressed: vm.listLoading ? null : () => vm.load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => vm.load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l.taskScreenSubtitle,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await context.pushNamed('createTask');
                if (mounted) await vm.load();
              },
              icon: const Icon(Icons.add),
              label: Text(l.taskCreate),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final entry in [
                  ('open', AppColors.primary),
                  ('in_progress', AppColors.warning),
                  ('completed', AppColors.success),
                ])
                  Expanded(
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 4,
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              backgroundColor: entry.$2.withValues(alpha: .12),
                              foregroundColor: entry.$2,
                              child: Text(
                                '${vm.summary[entry.$1] ?? '—'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              taskLabel(context, entry.$1),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: search,
              decoration: InputDecoration(
                labelText: l.taskSearch,
                prefixIcon: const Icon(Icons.search),
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
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l.taskAllTypes),
                    selected: !vm.filters.containsKey('task_type'),
                    onSelected: (_) {
                      vm.filters = {...vm.filters}..remove('task_type');
                      vm.load();
                    },
                  ),
                  for (final type in [
                    TaskKind.repair,
                    TaskKind.chore,
                    TaskKind.general,
                  ])
                    ChoiceChip(
                      label: Text(taskLabel(context, type.name)),
                      selected: vm.filters['task_type'] == type.name,
                      onSelected: (_) {
                        vm.filters = {...vm.filters, 'task_type': type.name};
                        vm.load();
                      },
                    ),
                  Chip(label: Text(l.taskShoppingSoon)),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
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
                  icon: const Icon(Icons.tune),
                  label: Text(l.taskFilters),
                ),
                FilterChip(
                  label: Text(l.taskAssignedToMe),
                  selected: vm.filters['assignment'] == 'me',
                  onSelected: (v) {
                    vm.filters = {...vm.filters, 'assignment': v ? 'me' : 'all'}
                      ..remove('assigned_to');
                    vm.load();
                  },
                ),
                FilterChip(
                  label: Text(l.taskUnassigned),
                  selected: vm.filters['assignment'] == 'unassigned',
                  onSelected: (v) {
                    vm.filters = {
                      ...vm.filters,
                      'assignment': v ? 'unassigned' : 'all',
                    }..remove('assigned_to');
                    vm.load();
                  },
                ),
                FilterChip(
                  label: Text(l.taskArchived),
                  selected: vm.archived,
                  onSelected: (v) {
                    vm.filters = {...vm.filters, 'archived': '$v'};
                    vm.load();
                  },
                ),
              ],
            ),
            if (vm.listCached) TaskNotice(l.taskCached),
            if (vm.errorCode != null)
              TaskNotice(taskError(context, vm.errorCode)),
            if (vm.listLoading) const LinearProgressIndicator(),
            if (!vm.listLoading && vm.items.isEmpty && vm.errorCode == null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 38,
                      backgroundColor: AppColors.lightBlue,
                      child: Icon(
                        Icons.task_alt,
                        size: 38,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      vm.filters.isEmpty ? l.taskEmpty : l.taskNoResults,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            for (final task in vm.items)
              TaskCard(
                task: task,
                onTap: () async {
                  await context.pushNamed(
                    'taskDetails',
                    pathParameters: {'id': task.id},
                  );
                  if (mounted) await vm.load();
                },
              ),
            if (vm.items.length < vm.total)
              TextButton(
                onPressed: vm.listLoading
                    ? null
                    : () => vm.load(nextPage: true),
                child: Text(l.taskLoadMore),
              ),
          ],
        ),
      ),
    );
  }
}
