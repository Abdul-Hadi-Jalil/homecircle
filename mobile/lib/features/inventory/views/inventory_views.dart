import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../models/inventory_item.dart';
import '../viewmodels/inventory_view_model.dart';
import '../../tasks/widgets/related_repairs.dart';
import '../../tasks/widgets/task_widgets.dart';

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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InventoryViewModel>();
    return AppScaffold(
      title: 'Inventory',
      actions: [
        IconButton(
          tooltip: 'Refresh inventory',
          onPressed: vm.loading ? null : () => vm.load(),
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Add inventory item',
          onPressed: () async {
            await context.pushNamed('addInventory');
            if (mounted) await vm.load();
          },
          icon: const Icon(Icons.add),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => vm.load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Everything your household keeps',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in [
                  'total',
                  'low_stock',
                  'out_of_stock',
                  'needs_repair',
                ])
                  Chip(
                    label: Text(
                      '${inventoryLabel(entry)}: ${vm.summary[entry] ?? '—'}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: search,
              decoration: const InputDecoration(
                labelText: 'Search inventory',
                prefixIcon: Icon(Icons.search),
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showInventoryFilters(context, vm),
                  icon: const Icon(Icons.tune),
                  label: const Text('Filters'),
                ),
                FilterChip(
                  label: const Text('Archived'),
                  selected: vm.archived,
                  onSelected: (value) {
                    vm.filters = {...vm.filters, 'archived': '$value'};
                    vm.load();
                  },
                ),
              ],
            ),
            if (vm.cached)
              const _Notice(
                'Showing saved inventory. Photos require a connection.',
              ),
            if (vm.error != null) _Notice(vm.error!),
            if (vm.loading) const LinearProgressIndicator(),
            if (!vm.loading && vm.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No items found. Add an item or change your filters.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final item in vm.items)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.lightBlue,
                    child: Icon(
                      item.consumable
                          ? Icons.kitchen_outlined
                          : Icons.home_repair_service_outlined,
                    ),
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${item.category} · ${item.location.isEmpty ? 'No location' : item.location}\n'
                    '${item.consumable ? '${item.quantity} ${item.unit} · ' : ''}${inventoryLabel(item.status)}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
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
                child: const Text('Load more items'),
              ),
          ],
        ),
      ),
    );
  }
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
    return AppScaffold(
      title: 'Item details',
      actions: [
        IconButton(
          tooltip: 'Refresh item',
          onPressed: vm.loading ? null : () => vm.open(widget.id),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (vm.error != null) _Notice(vm.error!),
          if (vm.cached)
            const _Notice(
              'Saved copy. Reconnect and refresh before making changes.',
            ),
          if (vm.loading) const LinearProgressIndicator(),
          if (item != null && item.id == widget.id) ...[
            if (vm.photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(vm.photo!, height: 220, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            Text(item.name, style: Theme.of(context).textTheme.headlineMedium),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(inventoryLabel(item.status))),
                if (item.archived) const Chip(label: Text('Archived')),
              ],
            ),
            Text(
              '${item.category} · ${item.location.isEmpty ? 'No location' : item.location}',
            ),
            if (item.consumable) ...[
              const SizedBox(height: 16),
              Text(
                '${item.quantity} ${item.unit}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                'Minimum stock: ${item.data['minimum_quantity'] ?? 'Not set'}',
              ),
            ],
            if (!item.consumable) ...[
              const SizedBox(height: 16),
              if (item.data['purchase_date'] != null)
                Text('Purchased: ${item.data['purchase_date']}'),
              if (item.data['last_service_date'] != null)
                Text('Last serviced: ${item.data['last_service_date']}'),
            ],
            if ((item.data['notes'] as String?)?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(item.data['notes'] as String),
              ),
            Text(
              'Updated ${item.data['updated_at']}\nBy ${item.data['updated_by_name'] ?? 'Household member'}',
            ),
            const SizedBox(height: 24),
            if (!item.archived) ...[
              FilledButton.icon(
                onPressed: vm.busy || vm.cached
                    ? null
                    : () async {
                        await context.pushNamed(
                          'editInventory',
                          pathParameters: {'id': item.id},
                        );
                        if (mounted) await vm.open(item.id);
                      },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit item'),
              ),
              const SizedBox(height: 8),
              if (item.consumable)
                OutlinedButton(
                  onPressed: vm.busy || vm.cached
                      ? null
                      : () => showQuantitySheet(context, vm, item),
                  child: const Text('Update quantity'),
                ),
              if (!item.consumable)
                inventoryDropdown(
                  'Condition',
                  item.status,
                  inventoryConditions
                      .map((v) => (v, inventoryLabel(v)))
                      .toList(),
                  vm.busy || vm.cached
                      ? null
                      : (value) async {
                          if (value != null &&
                              !vm.busy &&
                              !vm.cached &&
                              await vm.condition(item, value) != null) {
                            await vm.open(item.id);
                          }
                        },
                ),
              OutlinedButton.icon(
                onPressed: vm.busy || vm.cached
                    ? null
                    : () => pickPhoto(vm, item),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  item.photoPath == null ? 'Add photo' : 'Replace photo',
                ),
              ),
              if (item.photoPath != null)
                TextButton(
                  onPressed: vm.busy || vm.cached
                      ? null
                      : () async {
                          if (await vm.removePhoto(item) != null) {
                            await vm.open(item.id);
                          }
                        },
                  child: const Text('Remove photo'),
                ),
            ],
            TextButton.icon(
              onPressed: vm.busy || vm.cached
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            item.archived
                                ? 'Restore this item?'
                                : 'Archive this item?',
                          ),
                          content: Text(
                            item.archived
                                ? 'The item will return to the household inventory.'
                                : 'You can find and restore it using the Archived filter.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                item.archived ? 'Restore' : 'Archive',
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true &&
                          mounted &&
                          await vm.archive(item) != null) {
                        await vm.open(item.id);
                      }
                    },
              icon: Icon(
                item.archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              label: Text(item.archived ? 'Restore item' : 'Archive item'),
            ),
            const Divider(height: 40),
            Text('Activity', style: Theme.of(context).textTheme.titleLarge),
            if (vm.activity.isEmpty) const Text('No saved activity available.'),
            for (final event in vm.activity)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text(inventoryLabel(event['action'] as String)),
                subtitle: Text(
                  '${event['actor_name'] ?? 'Former household member'} · ${event['created_at']}\n'
                  '${(event['changes'] as Map? ?? {}).entries.map((e) => '${inventoryLabel(e.key.toString())}: ${(e.value as Map)['before'] ?? '—'} → ${(e.value as Map)['after'] ?? '—'}').join('\n')}',
                ),
              ),
            if (vm.moreActivity)
              TextButton(
                onPressed: vm.loadActivity,
                child: const Text('More activity'),
              ),
            if (!item.archived)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.add_shopping_cart),
                  title: Text(context.taskCopy.shoppingAddToList),
                  onTap: () => context.pushNamed(
                    'addShopping',
                    queryParameters: {
                      'item': item.id,
                      'name': item.name,
                      if (item.consumable) 'unit': item.unit,
                    },
                  ),
                ),
              ),
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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InventoryViewModel>();
    return AppScaffold(
      title: widget.id == null ? 'Add inventory item' : 'Edit inventory item',
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (vm.error != null) _Notice(vm.error!),
          if (!initialized) ...[
            if (vm.loading) const LinearProgressIndicator(),
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
                    'Keep your home organized',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const _Notice(
                    'Changes are saved as a draft on this device. They are sent only when you tap Save item. Add photos from item details after saving.',
                  ),
                  if (restoredDraft)
                    const _Notice('Your saved draft has been restored.'),
                  TextFormField(
                    controller: fields['name'],
                    maxLength: 150,
                    decoration: const InputDecoration(labelText: 'Item name'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter an item name.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  inventoryDropdown(
                    'Item type',
                    type,
                    [('consumable', 'Consumable'), ('durable', 'Durable')],
                    (value) => setState(() {
                      type = value!;
                      draft();
                    }),
                  ),
                  const SizedBox(height: 16),
                  inventoryDropdown(
                    'Category',
                    category ?? '',
                    [
                      ('', 'Uncategorized'),
                      ...vm.categories.map(
                        (row) => (row['id'] as String, row['name'] as String),
                      ),
                    ],
                    (value) {
                      setState(() => category = value == '' ? null : value);
                      draft();
                    },
                  ),
                  TextButton.icon(
                    onPressed: vm.busy
                        ? null
                        : () async {
                            final name = await showDialog<String>(
                              context: context,
                              builder: (context) => const _CategoryDialog(),
                            );
                            if (name != null && mounted) {
                              await vm.addCategory(name);
                            }
                          },
                    icon: const Icon(Icons.add),
                    label: const Text('New category'),
                  ),
                  if (type == 'consumable') ...[
                    TextFormField(
                      controller: fields['quantity'],
                      validator: quantityError,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                    const SizedBox(height: 16),
                    inventoryDropdown(
                      'Unit',
                      unit,
                      inventoryUnits.map((u) => (u, u)).toList(),
                      (v) {
                        unit = v!;
                        draft();
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: fields['minimum_quantity'],
                      validator: (v) => quantityError(v, optional: true),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Minimum stock (optional)',
                      ),
                    ),
                  ] else ...[
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
                      const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: fields['location'],
                    maxLength: 150,
                    decoration: const InputDecoration(
                      labelText: 'Storage location',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: fields['notes'],
                    maxLength: 4000,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  if (vm.error != null) _Notice(vm.error!),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: vm.busy
                        ? null
                        : () async {
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
                    child: Text(vm.busy ? 'Saving…' : 'Save item'),
                  ),
                  TextButton(
                    onPressed: vm.busy
                        ? null
                        : () async {
                            await vm.clearDraft(keyName);
                            if (context.mounted) context.pop();
                          },
                    child: const Text('Discard draft'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New category'),
    content: TextField(
      controller: name,
      maxLength: 80,
      decoration: const InputDecoration(labelText: 'Category name'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (name.text.trim().isNotEmpty) {
            Navigator.pop(context, name.text.trim());
          }
        },
        child: const Text('Create'),
      ),
    ],
  );
}
