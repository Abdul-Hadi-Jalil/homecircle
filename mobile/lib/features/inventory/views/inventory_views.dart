import 'dart:async';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/mock_widgets.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../household/viewmodels/session_view_model.dart';
import '../models/inventory_item.dart';
import '../viewmodels/inventory_view_model.dart';
import '../../tasks/widgets/related_repairs.dart';
import '../../tasks/widgets/task_widgets.dart';

export 'inventory_overview.dart' show InventoryOverview;

const inventoryUnits = [
  'piece',
  'pack',
  'kg',
  'g',
  'L',
  'mL',
  'bottle',
  'box',
  'roll',
];
const inventoryConditions = ['working', 'needs_repair', 'broken'];

String? quantityError(String? value, {bool optional = false}) {
  if (optional && (value == null || value.trim().isEmpty)) return null;
  final text = value?.trim() ?? '';
  if (!RegExp(r'^\d{1,12}(\.\d{1,3})?$').hasMatch(text) ||
      Decimal.tryParse(text) == null) {
    return 'Enter a nonnegative number with up to 3 decimal places.';
  }
  return null;
}

DropdownButtonFormField<String> inventoryDropdown(
  String label,
  String? value,
  List<(String, String)> options,
  ValueChanged<String?>? changed,
) => DropdownButtonFormField<String>(
  key: ValueKey('$label-$value'),
  initialValue: options.any((option) => option.$1 == value) ? value : null,
  isExpanded: true,
  decoration: InputDecoration(labelText: label),
  items: options
      .map(
        (option) => DropdownMenuItem(value: option.$1, child: Text(option.$2)),
      )
      .toList(),
  onChanged: changed,
);

Future<void> showInventoryFilters(
  BuildContext context,
  InventoryViewModel vm,
) async {
  final filters = {...vm.filters};
  var location = filters['location'] ?? '';
  final applied = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Filter inventory',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                for (final field in [
                  'type',
                  'category',
                  'stock_status',
                  'condition',
                  'sort',
                ]) ...[
                  inventoryDropdown(
                    inventoryLabel(field),
                    filters[field] ?? '',
                    [
                      ('', 'All'),
                      if (field == 'type') ...[
                        ('consumable', 'Consumable'),
                        ('durable', 'Durable'),
                      ],
                      if (field == 'category')
                        ...vm.categories.map(
                          (row) => (row['id'] as String, row['name'] as String),
                        ),
                      if (field == 'stock_status')
                        ...[
                          'available',
                          'low_stock',
                          'out_of_stock',
                        ].map((v) => (v, inventoryLabel(v))),
                      if (field == 'condition')
                        ...inventoryConditions.map(
                          (v) => (v, inventoryLabel(v)),
                        ),
                      if (field == 'sort')
                        ...[
                          'updated',
                          'name',
                          'oldest',
                        ].map((v) => (v, inventoryLabel(v))),
                    ],
                    (value) => setState(() {
                      if (value == '' || value == null) {
                        filters.remove(field);
                      } else {
                        filters[field] = value;
                      }
                    }),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  initialValue: location,
                  onChanged: (value) => location = value,
                  decoration: const InputDecoration(
                    labelText: 'Storage location (exact match)',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  children: [
                    TextButton(
                      onPressed: () {
                        filters.clear();
                        location = '';
                        Navigator.pop(context, true);
                      },
                      child: const Text('Clear filters'),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (location.trim().isNotEmpty) {
                          filters['location'] = location.trim();
                        } else {
                          filters.remove('location');
                        }
                        Navigator.pop(context, true);
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (applied == true && context.mounted) {
    vm.filters = filters;
    await vm.load();
  }
}

class InventoryDetails extends StatefulWidget {
  const InventoryDetails({required this.id, super.key});
  final String id;
  @override
  State<InventoryDetails> createState() => _InventoryDetailsState();
}

class _InventoryDetailsState extends State<InventoryDetails> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<InventoryViewModel>().open(widget.id);
    });
  }

  Future<void> pickPhoto(InventoryViewModel vm, InventoryItem item) async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 85,
      );
      if (file == null || !mounted || vm.item?.id != item.id) return;
      final bytes = await file.readAsBytes();
      if (!mounted || vm.item?.id != item.id) return;
      if (bytes.length > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a photo up to 5 MiB.')),
        );
        return;
      }
      if (await vm.upload(item, bytes) != null) await vm.open(item.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo selection failed. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InventoryViewModel>(), item = vm.item;
    final ready = item != null && item.id == widget.id;
    final locked = vm.busy || vm.cached;
    return AppScaffold(
      title: 'Item details',
      appBar: BrandAppBar(
        title: 'Inventory Item Details',
        showLogo: false,
        onBack: () =>
            context.canPop() ? context.pop() : context.goNamed('inventory'),
        onProfile: () => context.goNamed('profile'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More options',
            icon: const Icon(Icons.more_vert, color: AppColors.text),
            onSelected: (value) async {
              if (value == 'refresh') {
                await vm.open(widget.id);
              } else if (ready && value == 'edit') {
                await context.pushNamed(
                  'editInventory',
                  pathParameters: {'id': item.id},
                );
                if (mounted) await vm.open(item.id);
              } else if (ready && value == 'archive') {
                final confirmed = await showConfirmDialog(
                  context,
                  title: item.archived
                      ? 'Restore this item?'
                      : 'Archive this item?',
                  message: item.archived
                      ? 'The item will return to the household inventory.'
                      : 'You can find and restore it using the Archived filter.',
                  confirmLabel: item.archived ? 'Restore' : 'Archive',
                  cancelLabel: 'Cancel',
                  icon: item.archived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                );
                if (confirmed && mounted && await vm.archive(item) != null) {
                  await vm.open(item.id);
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Text('Refresh item'),
              ),
              if (ready && !item.archived)
                const PopupMenuItem(value: 'edit', child: Text('Edit item')),
              if (ready)
                PopupMenuItem(
                  value: 'archive',
                  child: Text(item.archived ? 'Restore item' : 'Archive item'),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
        children: [
          if (vm.error != null) _Notice(vm.error!),
          if (vm.cached)
            const _Notice(
              'Saved copy. Reconnect and refresh before making changes.',
            ),
          if (vm.loading) const LinearProgressIndicator(minHeight: 2),
          if (ready) ...[
            _ItemHeader(item: item),
            const SizedBox(height: 16),
            if (item.consumable) ...[
              _StockGauge(item: item),
              const SizedBox(height: 16),
              if (!item.archived)
                _TallyCard(
                  key: ValueKey('tally-${item.id}-${item.quantity}'),
                  item: item,
                  locked: locked,
                  onSave: (value) async {
                    final result = await vm.quantity(item, 'set', value);
                    if (result != null && mounted) await vm.open(item.id);
                  },
                  onShopping: () => context.pushNamed(
                    'addShopping',
                    queryParameters: {
                      'item': item.id,
                      'name': item.name,
                      if (item.consumable) 'unit': item.unit,
                    },
                  ),
                  onReport: () => context.pushNamed(
                    'createTask',
                    queryParameters: {
                      'item': item.id,
                      'itemName': item.name,
                      'type': 'repair',
                    },
                  ),
                  onExact: () => showQuantitySheet(context, vm, item),
                ),
            ] else ...[
              _ConditionCard(
                item: item,
                locked: locked || item.archived,
                onChanged: (value) async {
                  if (!vm.busy &&
                      !vm.cached &&
                      await vm.condition(item, value) != null) {
                    await vm.open(item.id);
                  }
                },
              ),
              if (!item.archived) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppCta(
                        label: context.taskCopy.shoppingAddToList,
                        icon: Icons.add_shopping_cart,
                        color: AppColors.surfaceContainer,
                        foreground: AppColors.primary,
                        shadow: false,
                        onPressed: () => context.pushNamed(
                          'addShopping',
                          queryParameters: {'item': item.id, 'name': item.name},
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 16),
            _PhotoCard(
              item: item,
              photo: vm.photo,
              locked: locked || item.archived,
              onPick: () => pickPhoto(vm, item),
              onRemove: () async {
                if (await vm.removePhoto(item) != null) await vm.open(item.id);
              },
            ),
            if ((item.data['notes'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              AppCard(
                radius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.sticky_note_2_outlined,
                          size: 22,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Notes & Preferences',
                          style: AppText.titleMd.copyWith(
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsetsDirectional.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.data['notes'] as String,
                        style: AppText.bodyMd.copyWith(
                          color: AppColors.text,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _LogCard(vm: vm),
            const SizedBox(height: 16),
            RelatedRepairs(
              key: ValueKey('repairs-${item.id}'),
              itemId: item.id,
              itemName: item.name,
              canCreate: !item.archived,
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemHeader extends StatelessWidget {
  const _ItemHeader({required this.item});
  final InventoryItem item;
  @override
  Widget build(BuildContext context) {
    final bad = item.status == 'out_of_stock' || item.status == 'broken';
    final warn = item.status == 'low_stock' || item.status == 'needs_repair';
    final (tileBg, tileFg) = bad
        ? (const Color(0x66FFDAD6), AppColors.danger)
        : warn
        ? (const Color(0x80FFDDB5), AppColors.tertiary)
        : (AppColors.secondaryContainer.withAlpha(120), AppColors.secondary);
    final (pillBg, pillFg) = bad
        ? (const Color(0xFFFFDAD6), AppColors.danger)
        : warn
        ? (AppColors.tertiaryFixed, AppColors.tertiary)
        : (AppColors.secondaryContainer, AppColors.onSecondaryContainer);
    return AppCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                icon: item.consumable
                    ? Icons.inventory_2_outlined
                    : Icons.home_repair_service_outlined,
                bg: tileBg,
                fg: tileFg,
                size: 56,
                iconSize: 28,
                radius: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          item.name,
                          style: AppText.headlineMd.copyWith(
                            color: AppColors.text,
                          ),
                        ),
                        AppPill(
                          item.consumable ? 'Consumable' : 'Durable',
                          bg: AppColors.primaryFixed,
                          fg: AppColors.primary,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: AppColors.tertiary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.location.isEmpty
                                ? 'No location'
                                : item.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyMd.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppPill(
                inventoryLabel(item.status),
                bg: pillBg,
                fg: pillFg,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppPill(
                item.category,
                icon: Icons.local_offer_outlined,
                bg: AppColors.surfaceLow,
                fg: AppColors.text,
                radius: 8,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                style: AppText.labelMd.copyWith(letterSpacing: 0),
              ),
              if (item.archived)
                AppPill(
                  'Archived',
                  bg: AppColors.surfaceHighest,
                  fg: AppColors.muted,
                  radius: 8,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockGauge extends StatelessWidget {
  const _StockGauge({required this.item});
  final InventoryItem item;
  @override
  Widget build(BuildContext context) {
    final qty = double.tryParse(item.quantity) ?? 0;
    final min = double.tryParse('${item.data['minimum_quantity'] ?? ''}');
    final ratio = min == null || min == 0
        ? null
        : (qty / (min * 2)).clamp(0.0, 1.0);
    final below = min != null && qty < min;
    final color = item.status == 'out_of_stock'
        ? AppColors.danger
        : below
        ? AppColors.tertiaryContainer
        : AppColors.secondary;
    final updated = DateTime.tryParse('${item.data['updated_at'] ?? ''}');
    return AppCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.bar_chart,
                    size: 22,
                    color: AppColors.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Stock Gauge',
                    style: AppText.titleMd.copyWith(color: AppColors.text),
                  ),
                ],
              ),
              if (min != null)
                Flexible(
                  child: Text(
                    below ? 'Below minimum' : 'Above minimum',
                    overflow: TextOverflow.ellipsis,
                    style: AppText.labelMd.copyWith(
                      color: color,
                      letterSpacing: 0,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: ratio ?? (qty > 0 ? 1 : 0),
              minHeight: 10,
              color: color,
              backgroundColor: AppColors.surfaceContainer,
            ),
          ),
          if (min != null) ...[
            const SizedBox(height: 4),
            Text(
              'Minimum stock: ${item.data['minimum_quantity']} ${item.unit}',
              style: AppText.labelSm.copyWith(
                color: AppColors.muted,
                letterSpacing: 0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _GaugeCell(
                  label: 'CURRENT',
                  value: '${item.quantity} ${item.unit}',
                  tint: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GaugeCell(
                  label: 'MINIMUM',
                  value: min == null
                      ? 'Not set'
                      : '${item.data['minimum_quantity']} ${item.unit}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GaugeCell(
                  label: 'UPDATED',
                  value: updated == null
                      ? '—'
                      : DateFormat.MMMd().format(updated.toLocal()),
                  sub: '${item.data['updated_by_name'] ?? 'Household member'}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugeCell extends StatelessWidget {
  const _GaugeCell({
    required this.label,
    required this.value,
    this.sub,
    this.tint,
  });
  final String label;
  final String value;
  final String? sub;
  final Color? tint;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.all(10),
    decoration: BoxDecoration(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.labelSm.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          style: AppText.titleMd.copyWith(color: tint ?? AppColors.text),
        ),
        if (sub != null)
          Text(
            sub!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodySm.copyWith(color: AppColors.muted),
          ),
      ],
    ),
  );
}

class _TallyCard extends StatefulWidget {
  const _TallyCard({
    required this.item,
    required this.locked,
    required this.onSave,
    required this.onShopping,
    required this.onReport,
    required this.onExact,
    super.key,
  });
  final InventoryItem item;
  final bool locked;
  final Future<void> Function(String value) onSave;
  final VoidCallback onShopping;
  final VoidCallback onReport;
  final VoidCallback onExact;
  @override
  State<_TallyCard> createState() => _TallyCardState();
}

class _TallyCardState extends State<_TallyCard> {
  late double value = double.tryParse(widget.item.quantity) ?? 0;
  bool saving = false;
  double get original => double.tryParse(widget.item.quantity) ?? 0;
  String get text => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  @override
  Widget build(BuildContext context) {
    final changed = value != original;
    return AppCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fast Inventory Tally',
                style: AppText.titleMd.copyWith(color: AppColors.text),
              ),
              InkWell(
                onTap: widget.locked ? null : widget.onExact,
                child: Text(
                  'Tap to adjust',
                  style: AppText.labelMd.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsetsDirectional.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _Step(
                  icon: Icons.remove,
                  onTap: widget.locked || value <= 0
                      ? null
                      : () => setState(
                          () => value = (value - 1)
                              .clamp(0, 999999999)
                              .toDouble(),
                        ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: text,
                      style: AppText.headlineMd.copyWith(
                        color: AppColors.text,
                        fontSize: 24,
                      ),
                      children: [
                        TextSpan(
                          text: ' ${widget.item.unit}',
                          style: AppText.bodyMd.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                _Step(
                  icon: Icons.add,
                  onTap: widget.locked
                      ? null
                      : () => setState(() => value = value + 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCta(
            label: 'Save Stock Update',
            icon: Icons.check_circle_outline,
            color: AppColors.primary,
            loading: saving,
            onPressed: widget.locked || !changed
                ? null
                : () async {
                    setState(() => saving = true);
                    await widget.onSave(text);
                    if (mounted) setState(() => saving = false);
                  },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppCta(
                  label: 'Add to List',
                  icon: Icons.add_shopping_cart,
                  color: AppColors.surfaceContainer,
                  foreground: AppColors.primary,
                  shadow: false,
                  onPressed: widget.onShopping,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppCta(
                  label: 'Report Issue',
                  icon: Icons.warning_amber,
                  color: AppColors.surfaceLow,
                  foreground: AppColors.text,
                  shadow: false,
                  onPressed: widget.onReport,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 56,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.sm,
        ),
        child: Icon(
          icon,
          color: onTap == null ? AppColors.muted : AppColors.text,
        ),
      ),
    ),
  );
}

class _ConditionCard extends StatelessWidget {
  const _ConditionCard({
    required this.item,
    required this.locked,
    required this.onChanged,
  });
  final InventoryItem item;
  final bool locked;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 20,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Condition',
          style: AppText.titleMd.copyWith(color: AppColors.text),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsetsDirectional.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (final c in inventoryConditions)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: locked ? null : () => onChanged(c),
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: item.status == c
                            ? (c == 'working'
                                  ? AppColors.secondary
                                  : c == 'broken'
                                  ? AppColors.danger
                                  : AppColors.tertiaryContainer)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        inventoryLabel(c),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.labelMd.copyWith(
                          letterSpacing: 0,
                          color: item.status == c
                              ? Colors.white
                              : AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (item.data['purchase_date'] != null ||
            item.data['last_service_date'] != null) ...[
          const SizedBox(height: 12),
          if (item.data['purchase_date'] != null)
            Text(
              'Purchased: ${item.data['purchase_date']}',
              style: AppText.bodyMd.copyWith(color: AppColors.muted),
            ),
          if (item.data['last_service_date'] != null)
            Text(
              'Last serviced: ${item.data['last_service_date']}',
              style: AppText.bodyMd.copyWith(color: AppColors.muted),
            ),
        ],
      ],
    ),
  );
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.item,
    required this.photo,
    required this.locked,
    required this.onPick,
    required this.onRemove,
  });
  final InventoryItem item;
  final Uint8List? photo;
  final bool locked;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 20,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Item Photo',
          style: AppText.titleMd.copyWith(color: AppColors.text),
        ),
        const SizedBox(height: 12),
        if (photo != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(photo!, height: 200, fit: BoxFit.cover),
          )
        else
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.photo_camera_outlined,
              size: 32,
              color: AppColors.muted,
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: locked ? null : onPick,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(
                  item.photoPath == null ? 'Add photo' : 'Replace photo',
                  style: AppText.labelLg.copyWith(color: AppColors.primary),
                ),
              ),
            ),
            if (item.photoPath != null)
              TextButton(
                onPressed: locked ? null : onRemove,
                child: Text(
                  'Remove photo',
                  style: AppText.labelLg.copyWith(color: AppColors.danger),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.vm});
  final InventoryViewModel vm;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 20,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.history, size: 22, color: AppColors.muted),
            const SizedBox(width: 8),
            Text(
              'Household Log',
              style: AppText.titleMd.copyWith(color: AppColors.text),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (vm.activity.isEmpty)
          Text(
            'No saved activity available.',
            style: AppText.bodyMd.copyWith(color: AppColors.muted),
          ),
        for (final event in vm.activity)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsetsDirectional.only(top: 4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inventoryLabel(event['action'] as String),
                        style: AppText.labelLg.copyWith(color: AppColors.text),
                      ),
                      Text(
                        '${event['actor_name'] ?? 'Former household member'} · ${event['created_at']}',
                        style: AppText.bodySm.copyWith(color: AppColors.muted),
                      ),
                      if ((event['changes'] as Map? ?? {}).isNotEmpty)
                        Text(
                          (event['changes'] as Map).entries
                              .map(
                                (e) =>
                                    '${inventoryLabel(e.key.toString())}: ${(e.value as Map)['before'] ?? '—'} → ${(e.value as Map)['after'] ?? '—'}',
                              )
                              .join('\n'),
                          style: AppText.bodySm.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (vm.moreActivity)
          TextButton(
            onPressed: vm.loadActivity,
            child: Text(
              'More activity',
              style: AppText.labelLg.copyWith(color: AppColors.primary),
            ),
          ),
      ],
    ),
  );
}

Future<void> showQuantitySheet(
  BuildContext context,
  InventoryViewModel vm,
  InventoryItem item,
) async {
  final amount = TextEditingController();
  final form = GlobalKey<FormState>();
  var operation = 'increase', submitting = false;
  String? error;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Update quantity',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('${item.name} · ${item.quantity} ${item.unit}'),
                  const SizedBox(height: 16),
                  inventoryDropdown(
                    'Operation',
                    operation,
                    [
                      ('increase', 'Add'),
                      ('decrease', 'Use / subtract'),
                      ('set', 'Set exact amount'),
                    ],
                    (value) {
                      if (!submitting && value != null) {
                        setState(() => operation = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: quantityError,
                    decoration: InputDecoration(
                      labelText: 'Amount (${item.unit})',
                    ),
                  ),
                  if (error != null) _Notice(error!),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            if (!form.currentState!.validate()) return;
                            setState(() => submitting = true);
                            final result = await vm.quantity(
                              item,
                              operation,
                              amount.text.trim(),
                            );
                            if (!context.mounted) return;
                            if (result != null) {
                              Navigator.pop(context);
                              await vm.open(item.id);
                            } else {
                              setState(() {
                                submitting = false;
                                error = vm.error;
                              });
                            }
                          },
                    child: Text(submitting ? 'Saving…' : 'Save quantity'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // Wait until the bottom-sheet exit animation releases its text field.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  amount.dispose();
}

class InventoryEditor extends StatefulWidget {
  const InventoryEditor({this.id, super.key});
  final String? id;
  @override
  State<InventoryEditor> createState() => _InventoryEditorState();
}

class _InventoryEditorState extends State<InventoryEditor> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{
    for (final key in [
      'name',
      'quantity',
      'minimum_quantity',
      'location',
      'notes',
      'purchase_date',
      'last_service_date',
    ])
      key: TextEditingController(),
  };
  String type = 'consumable', unit = 'piece', condition = 'working';
  String? category;
  int? expected;
  bool initialized = false, restoredDraft = false;
  String get keyName => widget.id ?? 'new';
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final vm = context.read<InventoryViewModel>();
      await vm.load();
      if (!mounted) return;
      if (widget.id != null) {
        await vm.open(widget.id!);
        if (!mounted || vm.item == null) return;
      }
      final draft = vm.draft(keyName);
      final data =
          draft ?? (widget.id == null ? <String, dynamic>{} : vm.item!.data);
      for (final entry in fields.entries) {
        entry.value.text = '${data[entry.key] ?? ''}';
      }
      type = data['item_type'] as String? ?? 'consumable';
      unit = data['unit'] as String? ?? 'piece';
      condition = data['condition'] as String? ?? 'working';
      category = data['category_id'] as String?;
      expected = (data['expected_revision'] ?? data['revision']) as int?;
      if (mounted) {
        setState(() {
          initialized = true;
          restoredDraft = draft != null;
        });
      }
    });
  }

  Map<String, dynamic> values() => {
    'name': fields['name']!.text.trim(),
    'item_type': type,
    'category_id': category,
    'quantity': type == 'consumable' ? fields['quantity']!.text.trim() : null,
    'minimum_quantity':
        type == 'consumable' &&
            fields['minimum_quantity']!.text.trim().isNotEmpty
        ? fields['minimum_quantity']!.text.trim()
        : null,
    'unit': type == 'consumable' ? unit : null,
    'condition': type == 'durable' ? condition : null,
    for (final key in ['location', 'notes'])
      key: fields[key]!.text.trim().isEmpty ? null : fields[key]!.text.trim(),
    for (final key in ['purchase_date', 'last_service_date'])
      key: type == 'durable' && fields[key]!.text.isNotEmpty
          ? fields[key]!.text
          : null,
    if (widget.id != null) 'expected_revision': expected,
  };
  void draft() {
    if (initialized && mounted) {
      unawaited(
        context.read<InventoryViewModel>().saveDraft(keyName, values()),
      );
    }
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  void _stepQty(int delta) {
    final current = double.tryParse(fields['quantity']!.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, 999999999).toDouble();
    fields['quantity']!.text = next == next.roundToDouble()
        ? '${next.round()}'
        : '$next';
    setState(() {});
    draft();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InventoryViewModel>();
    final session = context.watch<SessionViewModel>();
    final qty = double.tryParse(fields['quantity']!.text.trim());
    final min = double.tryParse(fields['minimum_quantity']!.text.trim());
    final low = type == 'consumable' && qty != null && min != null && qty < min;
    final locations = {
      for (final item in vm.items)
        if (item.location.isNotEmpty) item.location,
    }.take(4).toList();
    return AppScaffold(
      title: widget.id == null ? 'Add inventory item' : 'Edit inventory item',
      appBar: BrandAppBar(
        title: widget.id == null ? 'Add Inventory Item' : 'Edit Inventory Item',
        showLogo: false,
        onBack: () =>
            context.canPop() ? context.pop() : context.goNamed('inventory'),
        onProfile: () => context.goNamed('profile'),
        actions: [
          if (initialized)
            PopupMenuButton<String>(
              tooltip: 'More options',
              icon: const Icon(Icons.more_vert, color: AppColors.text),
              onSelected: (_) async {
                await vm.clearDraft(keyName);
                if (context.mounted) context.pop();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'discard', child: Text('Discard draft')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
        children: [
          if (vm.error != null) _Notice(vm.error!),
          if (!initialized) ...[
            if (vm.loading) const LinearProgressIndicator(minHeight: 2),
            if (!vm.loading)
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back to inventory'),
              ),
          ],
          if (initialized)
            Form(
              key: form,
              onChanged: draft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    (session.activeHousehold?.name ?? '').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.labelSm.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 0.55,
                    ),
                  ),
                  Text(
                    'Keep track of what you have at home.',
                    style: AppText.bodyMd.copyWith(color: AppColors.muted),
                  ),
                  if (restoredDraft)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 4),
                      child: Text(
                        'Your saved draft has been restored.',
                        style: AppText.bodySm.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Item Classification',
                    style: AppText.labelMd.copyWith(
                      color: AppColors.text,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _TypeTile(
                            icon: Icons.shopping_cart_outlined,
                            title: 'Consumable',
                            body: 'Supplies, food & cleaning with auto stock alerts',
                            selected: type == 'consumable',
                            onTap: () => setState(() {
                              type = 'consumable';
                              draft();
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TypeTile(
                            icon: Icons.precision_manufacturing_outlined,
                            title: 'Durable Asset',
                            body:
                                'Appliances, electronics & furniture condition',
                            selected: type == 'durable',
                            onTap: () => setState(() {
                              type = 'durable';
                              draft();
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    radius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 22,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Basic Information',
                              style: AppText.titleMd.copyWith(
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsetsDirectional.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const IconTile(
                                icon: Icons.photo_camera_outlined,
                                bg: Colors.white,
                                fg: AppColors.primary,
                                size: 48,
                                radius: 24,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add photos from item details after saving',
                                textAlign: TextAlign.center,
                                style: AppText.bodySm.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text.rich(
                              TextSpan(
                                text: 'Item Name',
                                children: [
                                  TextSpan(
                                    text: ' *',
                                    style: AppText.labelMd.copyWith(
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                              style: AppText.labelMd.copyWith(
                                color: AppColors.text,
                                letterSpacing: 0,
                              ),
                            ),
                            Text(
                              'Required',
                              style: AppText.labelMd.copyWith(
                                color: AppColors.muted,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: fields['name'],
                          maxLength: 150,
                          style: AppText.bodyLg.copyWith(color: AppColors.text),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'Item name',
                            suffixIcon: (fields['name']!.text.isEmpty)
                                ? null
                                : IconButton(
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      color: AppColors.muted,
                                    ),
                                    onPressed: () {
                                      fields['name']!.clear();
                                      setState(() {});
                                      draft();
                                    },
                                  ),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Enter an item name.'
                              : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Category',
                          style: AppText.labelMd.copyWith(
                            color: AppColors.text,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        inventoryDropdown(
                          'Category',
                          category ?? '',
                          [
                            ('', 'Uncategorized'),
                            ...vm.categories.map(
                              (row) =>
                                  (row['id'] as String, row['name'] as String),
                            ),
                          ],
                          (value) {
                            setState(
                              () => category = value == '' ? null : value,
                            );
                            draft();
                          },
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: vm.busy
                                ? null
                                : () async {
                                    final name = await showDialog<String>(
                                      context: context,
                                      builder: (context) =>
                                          const _CategoryDialog(),
                                    );
                                    if (name != null && mounted) {
                                      await vm.addCategory(name);
                                    }
                                  },
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(
                              'New category',
                              style: AppText.labelLg.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Storage Location',
                              style: AppText.labelMd.copyWith(
                                color: AppColors.text,
                                letterSpacing: 0,
                              ),
                            ),
                            if (locations.isNotEmpty)
                              Text(
                                'Quick select below',
                                style: AppText.labelMd.copyWith(
                                  color: AppColors.primary,
                                  letterSpacing: 0,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: fields['location'],
                          maxLength: 150,
                          style: AppText.bodyLg.copyWith(color: AppColors.text),
                          decoration: const InputDecoration(
                            counterText: '',
                            hintText: 'Storage location',
                            suffixIcon: Icon(
                              Icons.meeting_room_outlined,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        if (locations.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final place in locations)
                                InkWell(
                                  borderRadius: BorderRadius.circular(9999),
                                  onTap: () {
                                    fields['location']!.text = place;
                                    setState(() {});
                                    draft();
                                  },
                                  child: AppPill(
                                    place,
                                    bg: AppColors.surfaceContainer,
                                    fg: AppColors.text,
                                    padding:
                                        const EdgeInsetsDirectional.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                    style: AppText.labelMd.copyWith(
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (type == 'consumable')
                    AppCard(
                      radius: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 22,
                                      color: AppColors.secondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Stock & Restock Alerts',
                                        style: AppText.titleMd.copyWith(
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const AppPill(
                                'Active Tracker',
                                bg: AppColors.secondaryContainer,
                                fg: AppColors.onSecondaryContainer,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Current Quantity in Stock',
                            style: AppText.labelMd.copyWith(
                              color: AppColors.text,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _StepBtn(
                                icon: Icons.remove,
                                onTap: () => _stepQty(-1),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: fields['quantity'],
                                  validator: quantityError,
                                  textAlign: TextAlign.center,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  style: AppText.headlineSm.copyWith(
                                    color: AppColors.text,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '0',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StepBtn(
                                icon: Icons.add,
                                onTap: () => _stepQty(1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Measurement Unit',
                            style: AppText.labelMd.copyWith(
                              color: AppColors.text,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final u in inventoryUnits)
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: 8,
                                    ),
                                    child: Material(
                                      color: unit == u
                                          ? AppColors.primary
                                          : AppColors.surfaceContainer,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => setState(() {
                                          unit = u;
                                          draft();
                                        }),
                                        child: Container(
                                          constraints: const BoxConstraints(
                                            minWidth: 52,
                                          ),
                                          alignment: Alignment.center,
                                          padding:
                                              const EdgeInsetsDirectional.symmetric(
                                                horizontal: 14,
                                              ),
                                          child: Text(
                                            u,
                                            style: AppText.labelLg.copyWith(
                                              color: unit == u
                                                  ? Colors.white
                                                  : AppColors.text,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Minimum Desired Level',
                                style: AppText.labelMd.copyWith(
                                  color: AppColors.text,
                                  letterSpacing: 0,
                                ),
                              ),
                              Text(
                                'Triggers reminder',
                                style: AppText.labelMd.copyWith(
                                  color: AppColors.muted,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: fields['minimum_quantity'],
                            validator: (v) => quantityError(v, optional: true),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: AppText.bodyLg.copyWith(
                              color: AppColors.text,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Minimum stock (optional)',
                              suffixText: unit,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Alert household when remaining quantity drops below this amount.',
                            style: AppText.bodySm.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                          if (low) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsetsDirectional.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.tertiaryFixed,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.warning_amber,
                                    color: AppColors.tertiary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Will be marked as Low Stock',
                                          style: AppText.labelLg.copyWith(
                                            color: AppColors.onTertiaryFixed,
                                          ),
                                        ),
                                        Text(
                                          'Current stock (${fields['quantity']!.text.trim()} $unit) is less than the minimum threshold ($min $unit).',
                                          style: AppText.bodySm.copyWith(
                                            color: AppColors.onTertiaryFixed,
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
                    )
                  else
                    AppCard(
                      radius: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Condition',
                            style: AppText.titleMd.copyWith(
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 12),
                          inventoryDropdown(
                            'Condition',
                            condition,
                            inventoryConditions
                                .map((v) => (v, inventoryLabel(v)))
                                .toList(),
                            (v) {
                              condition = v!;
                              draft();
                            },
                          ),
                          for (final key in [
                            'purchase_date',
                            'last_service_date',
                          ]) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: fields[key],
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: inventoryLabel(key),
                                suffixIcon: IconButton(
                                  tooltip: 'Clear date',
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    fields[key]!.clear();
                                    draft();
                                  },
                                ),
                              ),
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now(),
                                  initialDate:
                                      DateTime.tryParse(fields[key]!.text) ??
                                      DateTime.now(),
                                );
                                if (date != null && mounted) {
                                  fields[key]!.text = date
                                      .toIso8601String()
                                      .substring(0, 10);
                                  draft();
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  AppCard(
                    radius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.notes,
                                  size: 22,
                                  color: AppColors.muted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Family Notes & Preferences',
                                  style: AppText.titleMd.copyWith(
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: fields['notes'],
                          maxLength: 4000,
                          minLines: 3,
                          maxLines: 5,
                          style: AppText.bodyMd.copyWith(color: AppColors.text),
                          decoration: const InputDecoration(
                            counterText: '',
                            hintText: 'Notes (optional)',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (vm.error != null) _Notice(vm.error!),
                  const SizedBox(height: 16),
                  AppCta(
                    label: vm.busy ? 'Saving…' : 'Save Item Changes',
                    icon: Icons.save_outlined,
                    color: AppColors.primary,
                    loading: vm.busy,
                    onPressed: () async {
                      if (!form.currentState!.validate()) return;
                      final saved = await vm.save(widget.id, values());
                      if (saved != null && mounted) {
                        await vm.clearDraft(keyName);
                        if (!context.mounted) return;
                        if (widget.id != null) {
                          context.pop();
                        } else {
                          context.pushReplacementNamed(
                            'inventoryDetails',
                            pathParameters: {'id': saved.id},
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: vm.busy
                        ? null
                        : () => context.canPop()
                              ? context.pop()
                              : context.goNamed('inventory'),
                    child: Text(
                      'Cancel',
                      style: AppText.labelLg.copyWith(color: AppColors.text),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primaryFixed.withAlpha(140) : Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsetsDirectional.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryFixed.withAlpha(140)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected ? null : AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconTile(
                  icon: icon,
                  bg: selected ? Colors.white : AppColors.surfaceContainer,
                  fg: AppColors.primary,
                  size: 36,
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_outline,
                    size: 22,
                    color: AppColors.primary,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppText.titleMd.copyWith(
                color: selected ? AppColors.primary : AppColors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(body, style: AppText.bodySm.copyWith(color: AppColors.muted)),
          ],
        ),
      ),
    ),
  );
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceLow,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Icon(icon, color: AppColors.text),
      ),
    ),
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog();
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final name = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialogFrame(
    title: 'New category',
    icon: Icons.label_outline,
    iconBg: AppColors.primaryFixed,
    iconFg: AppColors.primary,
    actions: [
      AppCta(
        label: 'Create',
        color: AppColors.primary,
        onPressed: () {
          if (name.text.trim().isNotEmpty) {
            Navigator.pop(context, name.text.trim());
          }
        },
      ),
      AppCta(
        label: 'Cancel',
        color: AppColors.surfaceContainer,
        foreground: AppColors.primary,
        shadow: false,
        onPressed: () => Navigator.pop(context),
      ),
    ],
    child: TextField(
      controller: name,
      maxLength: 80,
      decoration: const InputDecoration(labelText: 'Category name'),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
