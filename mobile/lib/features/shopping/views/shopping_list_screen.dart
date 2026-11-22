import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/mock_widgets.dart';
import '../../tasks/models/household_task.dart';
import '../../tasks/viewmodels/tasks_view_model.dart';
import '../../tasks/widgets/task_widgets.dart';
import '../viewmodels/shopping_list_viewmodel.dart';
import '../widgets/shopping_widgets.dart';
import '../widgets/shopping_purchase_sheet.dart';

const _outline = Color(0xFF747686);

/// "Shopping List" (UI/shared_shopping_list).
class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});
  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen>
    with WidgetsBindingObserver {
  final search = TextEditingController();
  final quick = TextEditingController();
  String quickUnit = 'pc';
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
    quick.dispose();
    super.dispose();
  }

  Future<void> _add({String? name, String? unit}) async {
    final vm = context.read<ShoppingListViewModel>();
    await context.pushNamed(
      'addShopping',
      queryParameters: {
        if (name != null && name.isNotEmpty) 'name': name,
        if (unit != null && unit.isNotEmpty) 'unit': unit,
      },
    );
    if (mounted) await vm.load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final vm = context.watch<ShoppingListViewModel>();
    final toBuy = vm.items
        .where((e) => !e.purchased && e.status != TaskStatus.cancelled)
        .toList();
    final bought = vm.items
        .where((e) => e.purchased && e.status != TaskStatus.cancelled)
        .toList();
    return AppScaffold(
      title: l.shoppingListTitle,
      appBar: BrandAppBar(
        title: l.appName,
        onBack: () =>
            context.canPop() ? context.pop() : context.goNamed('home'),
        onProfile: () => context.goNamed('profile'),
        actions: [
          IconButton(
            tooltip: l.taskRefresh,
            onPressed: vm.loading ? null : () => vm.load(),
            icon: const Icon(Icons.refresh, color: AppColors.text),
          ),
          IconButton(
            tooltip: l.shoppingHistory,
            onPressed: () => context.pushNamed('shoppingHistory'),
            icon: const Icon(Icons.history, color: AppColors.text),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => vm.load(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.shoppingListTitle,
                              style: AppText.headlineLg.copyWith(
                                color: AppColors.text,
                                letterSpacing: -0.65,
                              ),
                            ),
                            Text(
                              l.shoppingSubtitle,
                              style: AppText.bodySm.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const _ShoppingFilters(),
                          ),
                          child: Tooltip(
                            message: l.shoppingFiltersTooltip,
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(
                                Icons.tune,
                                size: 22,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 96,
                        child: AppCta(
                          label: l.shoppingAdd,
                          icon: Icons.add,
                          onPressed: _add,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ShoppingProgressCard(vm.summary),
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
                        hintText: l.shoppingSearch,
                        hintStyle: AppText.bodyMd.copyWith(color: _outline),
                        prefixIcon: const Icon(Icons.search, color: _outline),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsetsDirectional.symmetric(
                          vertical: 16,
                        ),
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
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final view in [
                          ('all', l.taskAny),
                          ('active', l.shoppingToBuy),
                          ('purchased', l.shoppingPurchased),
                          ('cancelled', l.shoppingCancelled),
                        ])
                          _ViewChip(
                            label: view.$2,
                            selected: (vm.filters['view'] ?? 'all') == view.$1,
                            onTap: () {
                              vm.filters = {...vm.filters, 'view': view.$1};
                              vm.load();
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.shoppingRefreshNote,
                    style: AppText.bodySm.copyWith(color: AppColors.muted),
                  ),
                  if (vm.cached) TaskNotice(l.taskCached),
                  if (vm.error != null)
                    TaskNotice(shoppingError(context, vm.error)),
                  if (vm.loading) const LinearProgressIndicator(minHeight: 2),
                  if (!vm.loading && vm.items.isEmpty && vm.error == null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 16),
                      child: AppCard(
                        radius: 16,
                        padding: const EdgeInsetsDirectional.all(24),
                        child: Column(
                          children: [
                            const IconTile(
                              icon: Icons.shopping_basket_outlined,
                              bg: AppColors.surfaceContainer,
                              fg: AppColors.primary,
                              size: 64,
                              iconSize: 32,
                              radius: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              vm.filters.values.any(
                                    (v) => v.isNotEmpty && v != 'all',
                                  )
                                  ? l.shoppingNoResults
                                  : l.shoppingEmpty,
                              textAlign: TextAlign.center,
                              style: AppText.bodyMd.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (vm.summary.total > 0 &&
                      vm.summary.active == 0 &&
                      !vm.loading)
                    TaskNotice(l.shoppingAllPurchased),
                  if (toBuy.isNotEmpty)
                    _GroupHeader(
                      title: l.shoppingToBuy,
                      count: toBuy.length,
                      countBg: AppColors.surfaceContainer,
                      countFg: AppColors.muted,
                      note: l.shoppingTapCheckbox,
                    ),
                  for (final item in toBuy)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 8),
                      child: _tile(context, vm, item),
                    ),
                  if (bought.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _GroupHeader(
                      title: l.shoppingPurchased,
                      count: bought.length,
                      countBg: AppColors.secondaryContainer,
                      countFg: AppColors.onSecondaryContainer,
                      leading: const Icon(
                        Icons.check_circle,
                        size: 24,
                        color: AppColors.secondary,
                      ),
                    ),
                    for (final item in bought)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: 8),
                        child: _tile(context, vm, item),
                      ),
                  ],
                  for (final item in vm.items.where(
                    (e) => e.status == TaskStatus.cancelled,
                  ))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 8),
                      child: Material(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text(
                            item.title,
                            style: AppText.titleMd.copyWith(
                              color: AppColors.muted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: Text(l.shoppingCancelled),
                          onTap: () => context.pushNamed(
                            'shoppingDetails',
                            pathParameters: {'id': item.id},
                          ),
                        ),
                      ),
                    ),
                  if (vm.items.length < vm.total)
                    TextButton(
                      onPressed: vm.loading
                          ? null
                          : () => vm.load(nextPage: true),
                      child: Text(
                        l.taskLoadMore,
                        style: AppText.labelLg.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          _QuickAddBar(
            controller: quick,
            unit: quickUnit,
            hint: l.shoppingQuickHint,
            label: l.shoppingAddShort,
            note: l.shoppingStockNote,
            onUnit: (u) => setState(() => quickUnit = u),
            onAdd: () async {
              final name = quick.text.trim();
              quick.clear();
              await _add(
                name: name,
                unit: quickUnit == 'pc' ? 'piece' : quickUnit,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, ShoppingListViewModel vm, dynamic item) =>
      ShoppingItemTile(
        item: item,
        busy: vm.busy || vm.cached,
        onTap: () async {
          await context.pushNamed(
            'shoppingDetails',
            pathParameters: {'id': item.id as String},
          );
          if (context.mounted) await vm.load();
        },
        onCheck: () => item.purchased as bool
            ? undoShopping(context, item)
            : purchaseShopping(context, item),
      );
}

class _ViewChip extends StatelessWidget {
  const _ViewChip({
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

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.count,
    required this.countBg,
    required this.countFg,
    this.note,
    this.leading,
  });
  final String title;
  final int count;
  final Color countBg;
  final Color countFg;
  final String? note;
  final Widget? leading;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 12, bottom: 8),
    child: Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Text(title, style: AppText.headlineMd.copyWith(color: AppColors.text)),
        const SizedBox(width: 8),
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: countBg, shape: BoxShape.circle),
          child: Text(
            '$count',
            style: AppText.labelSm.copyWith(color: countFg, letterSpacing: 0),
          ),
        ),
        if (note != null) ...[
          const Spacer(),
          Flexible(
            child: Text(
              note!,
              textAlign: TextAlign.end,
              maxLines: 2,
              style: AppText.labelSm.copyWith(
                color: AppColors.muted,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _QuickAddBar extends StatelessWidget {
  const _QuickAddBar({
    required this.controller,
    required this.unit,
    required this.hint,
    required this.label,
    required this.note,
    required this.onUnit,
    required this.onAdd,
  });
  final TextEditingController controller;
  final String unit;
  final String hint;
  final String label;
  final String note;
  final ValueChanged<String> onUnit;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(13),
          blurRadius: 16,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          style: AppText.bodyMd.copyWith(color: AppColors.text),
                          onSubmitted: (_) => onAdd(),
                          decoration: InputDecoration(
                            hintText: hint,
                            hintStyle: AppText.bodyMd.copyWith(color: _outline),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsetsDirectional.only(end: 6),
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: unit,
                            isDense: true,
                            style: AppText.labelMd.copyWith(
                              color: AppColors.text,
                              letterSpacing: 0,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'pc',
                                child: Text('1 pc'),
                              ),
                              DropdownMenuItem(value: 'kg', child: Text('kg')),
                              DropdownMenuItem(value: 'L', child: Text('L')),
                              DropdownMenuItem(
                                value: 'pack',
                                child: Text('pack'),
                              ),
                            ],
                            onChanged: (v) => onUnit(v ?? 'pc'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: AppCta(
                  label: label,
                  color: AppColors.primary,
                  onPressed: onAdd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SafeArea(
            top: false,
            child: Text(
              note,
              textAlign: TextAlign.center,
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
  );
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
