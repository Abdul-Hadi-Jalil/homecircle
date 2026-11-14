import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../tasks/models/household_task.dart';
import '../../tasks/viewmodels/tasks_view_model.dart';
import '../../tasks/widgets/task_widgets.dart';
import '../viewmodels/shopping_list_viewmodel.dart';
import '../widgets/shopping_widgets.dart';
import '../widgets/shopping_purchase_sheet.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});
  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen>
    with WidgetsBindingObserver {
  final search = TextEditingController();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted) {
        final vm = context.read<ShoppingListViewModel>();
        search.text = vm.filters['search'] ?? '';
        vm.load();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ShoppingListViewModel>().load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy, vm = context.watch<ShoppingListViewModel>();
    return AppScaffold(
      title: l.shoppingListTitle,
      actions: [
        IconButton(
          tooltip: l.taskRefresh,
          onPressed: vm.loading ? null : () => vm.load(),
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: l.shoppingHistory,
          onPressed: () => context.pushNamed('shoppingHistory'),
          icon: const Icon(Icons.history),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => vm.load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(child: Text(l.shoppingSubtitle)),
                FilledButton.icon(
                  onPressed: () async {
                    await context.pushNamed('addShopping');
                    if (context.mounted) await vm.load();
                  },
                  icon: const Icon(Icons.add),
                  label: Text(l.shoppingAdd),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ShoppingProgressCard(vm.summary),
            TextField(
              controller: search,
              decoration: InputDecoration(
                labelText: l.shoppingSearch,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) {
                timer?.cancel();
                timer = Timer(const Duration(milliseconds: 350), () {
                  if (mounted) {
                    vm.filters = {...vm.filters, 'search': v.trim()};
                    vm.load();
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const _ShoppingFilters(),
                    );
                  },
                  icon: const Icon(Icons.tune),
                  label: Text(l.taskFilters),
                ),
                for (final view in [
                  ('all', l.taskAny),
                  ('active', l.shoppingToBuy),
                  ('purchased', l.shoppingPurchased),
                  ('cancelled', l.shoppingCancelled),
                ])
                  ChoiceChip(
                    label: Text(view.$2),
                    selected: (vm.filters['view'] ?? 'all') == view.$1,
                    onSelected: (_) {
                      vm.filters = {...vm.filters, 'view': view.$1};
                      vm.load();
                    },
                  ),
              ],
            ),
            Text(
              l.shoppingRefreshNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (vm.cached) TaskNotice(l.taskCached),
            if (vm.error != null) TaskNotice(shoppingError(context, vm.error)),
            if (vm.loading) const LinearProgressIndicator(),
            if (!vm.loading && vm.items.isEmpty && vm.error == null)
              TaskSection(
                children: [
                  const Icon(Icons.shopping_basket_outlined, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    vm.filters.values.any((v) => v.isNotEmpty && v != 'all')
                        ? l.shoppingNoResults
                        : l.shoppingEmpty,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            if (vm.summary.total > 0 && vm.summary.active == 0 && !vm.loading)
              TaskNotice(l.shoppingAllPurchased),
            for (final group in [
              (false, l.shoppingToBuy),
              (true, l.shoppingPurchased),
            ]) ...[
              if (vm.items.any(
                (e) =>
                    e.purchased == group.$1 && e.status != TaskStatus.cancelled,
              ))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    group.$2,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              for (final item in vm.items.where(
                (e) =>
                    e.purchased == group.$1 && e.status != TaskStatus.cancelled,
              ))
                ShoppingItemTile(
                  item: item,
                  busy: vm.busy || vm.cached,
                  onTap: () async {
                    await context.pushNamed(
                      'shoppingDetails',
                      pathParameters: {'id': item.id},
                    );
                    if (context.mounted) await vm.load();
                  },
                  onCheck: () => item.purchased
                      ? undoShopping(context, item)
                      : purchaseShopping(context, item),
                ),
            ],
            for (final item in vm.items.where(
              (e) => e.status == TaskStatus.cancelled,
            ))
              ListTile(
                title: Text(item.title),
                subtitle: Text(l.shoppingCancelled),
                onTap: () => context.pushNamed(
                  'shoppingDetails',
                  pathParameters: {'id': item.id},
                ),
              ),
            if (vm.items.length < vm.total)
              TextButton(
                onPressed: vm.loading ? null : () => vm.load(nextPage: true),
                child: Text(l.taskLoadMore),
              ),
            OutlinedButton.icon(
              onPressed: () => context.pushNamed('addShopping'),
              icon: const Icon(Icons.add),
              label: Text(l.shoppingQuickAdd),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingFilters extends StatefulWidget {
  const _ShoppingFilters();
  @override
  State<_ShoppingFilters> createState() => _ShoppingFiltersState();
}

class _ShoppingFiltersState extends State<_ShoppingFilters> {
  late Map<String, String> values;
  @override
  void initState() {
    super.initState();
    values = {...context.read<ShoppingListViewModel>().filters};
    context.read<ShoppingListViewModel>().tasks.loadMembers();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy, vm = context.watch<ShoppingListViewModel>();
    final members = context.watch<TasksViewModel>().members;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.taskFilters, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            taskDropdown(l.taskPriority, values['priority'] ?? '', [
              ('', l.taskAny),
              for (final p in TaskPriority.values)
                (p.name, taskLabel(context, p.name)),
            ], (v) => setState(() => values['priority'] = v ?? '')),
            const SizedBox(height: 16),
            taskDropdown(
              l.taskAssignedTo,
              values['assignment'] ?? 'all',
              [
                ('all', l.taskAny),
                ('me', l.taskAssignedToMe),
                ('unassigned', l.taskUnassigned),
              ],
              (v) => setState(() {
                values['assignment'] = v ?? 'all';
                values.remove('assigned_to');
              }),
            ),
            const SizedBox(height: 16),
            AssigneeSelector(
              members: members,
              value: values['assigned_to'],
              onChanged: (v) => setState(() {
                if (v == null) {
                  values.remove('assigned_to');
                } else {
                  values['assigned_to'] = v;
                  values['assignment'] = 'all';
                }
              }),
            ),
            const SizedBox(height: 16),
            taskDropdown(l.taskSort, values['sort'] ?? 'priority', [
              ('priority', l.taskPriority),
              ('created', l.shoppingNewest),
              ('updated', l.taskSortUpdated),
            ], (v) => setState(() => values['sort'] = v ?? 'priority')),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(l.taskArchived),
              value: values['archived'] == 'true',
              onChanged: (v) => setState(() => values['archived'] = '$v'),
            ),
            FilledButton(
              onPressed: () {
                vm.filters = values..removeWhere((k, v) => v.isEmpty);
                vm.load();
                Navigator.pop(context);
              },
              child: Text(l.taskApplyFilters),
            ),
          ],
        ),
      ),
    );
  }
}
