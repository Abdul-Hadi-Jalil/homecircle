import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/mock_widgets.dart';
import '../../../core/widgets/skeleton.dart';
import '../models/inventory_item.dart';
import '../viewmodels/inventory_view_model.dart';
import 'inventory_views.dart' show showInventoryFilters;

const _outline = Color(0xFF747686);

/// "Inventory" tab (UI/inventory_overview).
class InventoryOverview extends StatefulWidget {
  const InventoryOverview({super.key});
  @override
  State<InventoryOverview> createState() => _InventoryOverviewState();
}

class _InventoryOverviewState extends State<InventoryOverview> {
  final search = TextEditingController();
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<InventoryViewModel>().load();
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final vm = context.read<InventoryViewModel>();
    await context.pushNamed('addInventory');
    if (mounted) await vm.load();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InventoryViewModel>();
    final selectedCategory = vm.filters['category'];
    final total = (vm.summary['total'] as num?)?.toInt();
    final low = (vm.summary['low_stock'] as num?)?.toInt();
    final out = (vm.summary['out_of_stock'] as num?)?.toInt() ?? 0;
    final repair = (vm.summary['needs_repair'] as num?)?.toInt();
    final available = total == null || low == null
        ? null
        : (total - low - out).clamp(0, total);
    return AppScaffold(
      title: 'Inventory',
      appBar: BrandAppBar(
        title: 'HomeCircle',
        onProfile: () => context.goNamed('profile'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add, size: 22),
        label: Text(
          'Add Item',
          style: AppText.labelLg.copyWith(color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => vm.load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 96),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory',
                        style: AppText.headlineLg.copyWith(
                          color: AppColors.text,
                          letterSpacing: -0.65,
                        ),
                      ),
                      Text(
                        'Everything in your home, organized.',
                        style: AppText.bodySm.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  child: Tooltip(
                    message: 'Add inventory item',
                    child: AppCta(
                      label: 'Add',
                      icon: Icons.add,
                      onPressed: _add,
                    ),
                  ),
                ),
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
                  hintText: 'Search household items...',
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
                onChanged: (text) {
                  debounce?.cancel();
                  debounce = Timer(const Duration(milliseconds: 350), () {
                    if (!mounted) return;
                    vm.filters = {...vm.filters, 'search': text.trim()};
                    vm.load();
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
                  _CategoryChip(
                    label: 'All',
                    selected: selectedCategory == null && !vm.archived,
                    onTap: () {
                      final next = {...vm.filters}
                        ..remove('category')
                        ..remove('archived');
                      vm.filters = next;
                      vm.load();
                    },
                  ),
                  for (final category in vm.categories)
                    _CategoryChip(
                      label: category['name'] as String,
                      selected: selectedCategory == category['id'],
                      onTap: () {
                        vm.filters = {
                          ...vm.filters,
                          'category': category['id'] as String,
                        };
                        vm.load();
                      },
                    ),
                  _CategoryChip(
                    label: 'Archived',
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
              children: [
                Expanded(
                  child: _StatTile(
                    dot: AppColors.secondary,
                    caption: 'STOCK',
                    value: available,
                    label: 'Available',
                    bg: const Color(0x4D82F9C1),
                    fg: AppColors.secondary,
                    onTap: () => _filterStock('available', vm),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    dot: AppColors.tertiary,
                    caption: 'ALERT',
                    value: low,
                    label: 'Low Stock',
                    bg: const Color(0x80FFDDB5),
                    fg: AppColors.tertiary,
                    onTap: () => _filterStock('low_stock', vm),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    dot: AppColors.danger,
                    caption: 'FIX',
                    value: repair,
                    label: 'Attention',
                    bg: const Color(0x66FFDAD6),
                    fg: AppColors.danger,
                    onTap: () {
                      vm.filters = {...vm.filters, 'condition': 'needs_repair'};
                      vm.load();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text.rich(
                      maxLines: 1,
                      softWrap: false,
                      TextSpan(
                        style: AppText.bodyMd.copyWith(color: AppColors.muted),
                        children: [
                          const TextSpan(text: 'Showing '),
                          TextSpan(
                            text: '${vm.total}',
                            style: AppText.bodyMd.copyWith(
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: vm.total == 1 ? ' item' : ' items'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: PopupMenuButton<String>(
                    tooltip: 'Sort items',
                    onSelected: (value) {
                      vm.filters = {...vm.filters, 'sort': value};
                      vm.load();
                    },
                    itemBuilder: (context) => [
                      for (final option in const [
                        ('updated', 'Recently Updated'),
                        ('name', 'Name'),
                        ('oldest', 'Oldest'),
                      ])
                        PopupMenuItem(value: option.$1, child: Text(option.$2)),
                    ],
                    child: Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppShadows.sm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Sort: ${_sortLabel(vm.filters['sort'])}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.labelMd.copyWith(
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
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
                const SizedBox(width: 8),
                Material(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => showInventoryFilters(context, vm),
                    child: const Tooltip(
                      message: 'Filters',
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.tune,
                          size: 20,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (vm.cached)
              const _Notice(
                'Showing saved inventory. Photos require a connection.',
              ),
            if (vm.error != null) _Notice(vm.error!),
            if (vm.loading && vm.items.isEmpty)
              for (var i = 0; i < 4; i++)
                const Padding(
                  padding: EdgeInsetsDirectional.only(bottom: 12),
                  child: InventoryCardSkeleton(),
                )
            else if (vm.loading)
              const LinearProgressIndicator(minHeight: 2),
            if (!vm.loading && vm.items.isEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.all(32),
                child: Text(
                  'No items found. Add an item or change your filters.',
                  textAlign: TextAlign.center,
                  style: AppText.bodyMd.copyWith(color: AppColors.muted),
                ),
              ),
            for (final item in vm.items)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 12),
                child: _ItemCard(
                  item: item,
                  onTap: () async {
                    await context.pushNamed(
                      'inventoryDetails',
                      pathParameters: {'id': item.id},
                    );
                    if (mounted) await vm.load();
                  },
                ),
              ),
            if (vm.items.length < vm.total)
              TextButton(
                onPressed: vm.loading ? null : () => vm.load(more: true),
                child: Text(
                  'Load more items',
                  style: AppText.labelLg.copyWith(color: AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _filterStock(String status, InventoryViewModel vm) {
    vm.filters = {...vm.filters, 'stock_status': status};
    vm.load();
  }

  String _sortLabel(String? sort) => switch (sort) {
    'name' => 'Name',
    'oldest' => 'Oldest',
    _ => 'Recently Updated',
  };
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
    child: Text(text, style: AppText.bodySm.copyWith(color: AppColors.primary)),
  );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
      color: selected ? AppColors.primaryContainer : Colors.white,
      borderRadius: BorderRadius.circular(9999),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryContainer : Colors.white,
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

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.dot,
    required this.caption,
    required this.value,
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });
  final Color dot;
  final String caption;
  final int? value;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: bg,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.labelSm.copyWith(color: fg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value == null ? '–' : '$value',
              style: AppText.headlineLg.copyWith(
                color: fg,
                fontSize: 24,
                height: 1.3,
                letterSpacing: 0,
              ),
            ),
            Text(
              label,
              maxLines: 2,
              style: AppText.labelMd.copyWith(color: fg, letterSpacing: 0),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onTap});
  final InventoryItem item;
  final VoidCallback onTap;

  ({Color tileBg, Color tileFg, Color pillBg, Color pillFg}) get _tone =>
      switch (item.status) {
        'low_stock' || 'needs_repair' => (
          tileBg: const Color(0x80FFDDB5),
          tileFg: AppColors.tertiary,
          pillBg: AppColors.tertiaryFixed,
          pillFg: AppColors.tertiary,
        ),
        'out_of_stock' || 'broken' => (
          tileBg: const Color(0x66FFDAD6),
          tileFg: AppColors.danger,
          pillBg: const Color(0xFFFFDAD6),
          pillFg: AppColors.danger,
        ),
        _ => (
          tileBg: item.consumable
              ? AppColors.secondaryFixed.withAlpha(120)
              : AppColors.primaryFixed.withAlpha(150),
          tileFg: item.consumable ? AppColors.secondary : AppColors.primary,
          pillBg: AppColors.secondaryContainer,
          pillFg: AppColors.onSecondaryContainer,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    final place = item.location.isEmpty ? '' : ' • ${item.location}';
    final good = item.status == 'available' || item.status == 'working';
    final info = item.consumable
        ? '${item.quantity} ${item.unit}${item.status == 'low_stock' ? ' left' : ''}'
        : 'Condition: ${inventoryLabel(item.status)}';
    final infoIcon = switch (item.status) {
      'low_stock' => Icons.hourglass_bottom,
      'out_of_stock' || 'broken' || 'needs_repair' => Icons.warning_amber,
      'working' => Icons.check_circle_outline,
      _ => Icons.inventory_2_outlined,
    };
    final infoBg = good && item.consumable
        ? AppColors.primaryFixed
        : tone.pillBg.withAlpha(good ? 150 : 255);
    final infoFg = good && item.consumable ? AppColors.primary : tone.pillFg;
    return Material(
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
          child: Row(
            children: [
              IconTile(
                icon: item.consumable
                    ? Icons.inventory_2_outlined
                    : Icons.home_repair_service_outlined,
                bg: tone.tileBg,
                fg: tone.tileFg,
                size: 60,
                iconSize: 26,
                radius: 12,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.headlineSm.copyWith(
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppPill(
                          inventoryLabel(item.status),
                          bg: tone.pillBg,
                          fg: tone.pillFg,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.category}$place',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyMd.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          child: AppPill(
                            info,
                            icon: infoIcon,
                            bg: infoBg,
                            fg: infoFg,
                            radius: 8,
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            style: AppText.labelMd.copyWith(letterSpacing: 0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.consumable ? 'Consumable' : 'Durable',
                          style: AppText.labelSm.copyWith(
                            color: AppColors.muted,
                            letterSpacing: 0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 22, color: _outline),
            ],
          ),
        ),
      ),
    );
  }
}
