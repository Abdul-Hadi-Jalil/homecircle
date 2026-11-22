import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/mock_widgets.dart';
import '../../tasks/models/household_task.dart';
import '../../tasks/viewmodels/tasks_view_model.dart';
import '../../tasks/views/task_form_screen.dart';
import '../../tasks/widgets/task_widgets.dart';
import '../viewmodels/shopping_list_viewmodel.dart';
import '../viewmodels/shopping_form_viewmodel.dart';
import '../widgets/shopping_widgets.dart';
import '../../chat/models/chat_task_source.dart';
import '../../chat/viewmodels/family_chat_viewmodel.dart';

const shoppingUnits = [
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
String? shoppingNumber(
  String? value,
  BuildContext context, {
  bool price = false,
}) {
  if (value == null || value.trim().isEmpty) return null;
  final pattern = price
      ? RegExp(r'^\d{1,13}(\.\d{1,2})?$')
      : RegExp(r'^\d{1,12}(\.\d{1,3})?$');
  if (!pattern.hasMatch(value.trim()) ||
      (!price && !RegExp(r'[1-9]').hasMatch(value))) {
    return price
        ? context.taskCopy.shoppingPriceError
        : context.taskCopy.shoppingNumberError;
  }
  return null;
}

class ShoppingItemForm extends StatefulWidget {
  const ShoppingItemForm({
    this.id,
    this.prefill = const {},
    this.chatSource,
    super.key,
  });
  final String? id;
  final Map<String, dynamic> prefill;
  final ChatTaskSource? chatSource;
  @override
  State<ShoppingItemForm> createState() => _ShoppingItemFormState();
}

class _ShoppingItemFormState extends State<ShoppingItemForm> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      quantity = TextEditingController(),
      notes = TextEditingController();
  ShoppingFormViewModel? model;
  @override
  void initState() {
    super.initState();
    Future.microtask(initialize);
  }

  Future<void> initialize() async {
    if (!mounted) return;
    final vm = context.read<ShoppingListViewModel>(),
        captured = context.read<ShoppingListViewModel>().scope;
    context.read<TasksViewModel>().loadMembers();
    context.read<TasksViewModel>().searchInventory('');
    final item = widget.id == null ? null : await vm.open(widget.id!);
    if (!mounted ||
        !vm.current(captured) ||
        (widget.id != null && item == null)) {
      return;
    }
    final source = widget.chatSource,
        cache = context.read<FamilyChatViewModel>().repository.cache;
    Map<String, dynamic>? secureDraft;
    if (source != null) {
      if (source.household != vm.household) return;
      try {
        secureDraft = await cache.read(
          vm.user!,
          source.household,
          'shopping.${source.messageId}',
        );
      } catch (_) {
        secureDraft = null;
      }
      if (!mounted || !vm.current(captured)) return;
    }
    model = ShoppingFormViewModel(
      vm,
      initial: item,
      prefill: widget.prefill,
      chatSource: source,
      chatCache: cache,
      secureDraft: secureDraft,
    );
    name.text = model!.fields['title'] as String? ?? '';
    quantity.text = model!.fields['quantity'] as String? ?? '';
    notes.text = model!.fields['description'] as String? ?? '';
    model!.addListener(changed);
    setState(() {});
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    model?.removeListener(changed);
    model?.dispose();
    name.dispose();
    quantity.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save({bool allowDuplicate = false}) async {
    final m = model;
    if (m == null || m.busy || !form.currentState!.validate()) return;
    final result = await m.submit(allowDuplicate: allowDuplicate);
    if (!mounted || !m.current) return;
    if (result != null) {
      context.pushReplacementNamed(
        'shoppingDetails',
        pathParameters: {'id': result.id},
      );
      return;
    }
    if (m.duplicates.isNotEmpty) {
      final existing = m.duplicates.first, l = context.taskCopy;
      final decision = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.shoppingDuplicate),
          content: Text(existing.title),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.shoppingViewExisting),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.shoppingAddAnother),
            ),
          ],
        ),
      );
      if (!mounted || !m.current) return;
      if (decision == true) {
        await save(allowDuplicate: true);
      } else if (decision == false) {
        context.pushNamed(
          'shoppingDetails',
          pathParameters: {'id': existing.id},
        );
      }
    }
  }

  void _step(ShoppingFormViewModel m, int delta) {
    final current = double.tryParse(quantity.text.trim()) ?? 0;
    final next = (current + delta).clamp(delta < 0 ? 0 : 1, 999999999);
    final text = next == next.roundToDouble() ? '${next.round()}' : '$next';
    quantity.text = text;
    m.update('quantity', text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final m = model;
    final vm = context.watch<ShoppingListViewModel>();
    final tasks = context.watch<TasksViewModel>();
    final members = tasks.members;
    return AppScaffold(
      title: widget.id == null ? l.shoppingAdd : l.taskEdit,
      appBar: BrandAppBar(
        title: widget.id == null ? l.shoppingAddItemTitle : l.taskEdit,
        showLogo: false,
        onBack: () =>
            context.canPop() ? context.pop() : context.goNamed('shopping'),
        onProfile: () => context.goNamed('profile'),
        actions: [
          if (m != null)
            PopupMenuButton<String>(
              tooltip: l.taskMoreOptions,
              icon: const Icon(Icons.more_vert, color: AppColors.text),
              onSelected: (_) async {
                await m.discardDraft();
                if (context.mounted) context.pop();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'discard',
                  child: Text(l.taskDiscardDraft),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 24),
        children: [
          if (vm.error != null) TaskNotice(shoppingError(context, vm.error)),
          if (m == null) const LinearProgressIndicator(minHeight: 2),
          if (m != null)
            Form(
              key: form,
              child: Container(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: AppShadows.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHighest,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.add_shopping_cart,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      (vm.session.activeHousehold?.name ?? '')
                                          .toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.labelSm.copyWith(
                                        color: AppColors.primary,
                                        letterSpacing: 0.55,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                l.shoppingSheetTitle,
                                style: AppText.headlineLg.copyWith(
                                  color: AppColors.text,
                                  letterSpacing: -0.65,
                                ),
                              ),
                              Text(
                                m.restored
                                    ? l.taskDraftRestored
                                    : l.shoppingSheetSubtitle,
                                style: AppText.bodyMd.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: l.cancel,
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.goNamed('shopping'),
                          icon: const Icon(Icons.close, color: AppColors.text),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: l.shoppingName,
                            children: [
                              TextSpan(
                                text: ' *',
                                style: AppText.labelLg.copyWith(
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                          style: AppText.labelLg.copyWith(
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          l.shoppingAutoSuggest,
                          style: AppText.labelMd.copyWith(
                            color: AppColors.muted,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: name,
                      maxLength: 150,
                      enabled: !m.busy,
                      style: AppText.headlineSm.copyWith(color: AppColors.text),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: l.shoppingName,
                        contentPadding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: name.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  color: AppColors.muted,
                                ),
                                onPressed: m.busy
                                    ? null
                                    : () {
                                        name.clear();
                                        m.update('title', '');
                                      },
                              ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? l.taskTitleRequired
                          : null,
                      onChanged: (v) => m.update('title', v),
                    ),
                    if (tasks.candidates.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final item in tasks.candidates.take(8))
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: 8,
                                ),
                                child: _SuggestChip(
                                  label: item['name'] as String,
                                  selected:
                                      name.text.trim() ==
                                      (item['name'] as String),
                                  onTap: m.busy
                                      ? null
                                      : () {
                                          name.text = item['name'] as String;
                                          m.update('title', name.text);
                                          m.update(
                                            'linked_inventory_item_id',
                                            item['id'],
                                          );
                                          m.update(
                                            'linked_inventory_name',
                                            item['name'],
                                          );
                                          if (item['unit'] != null) {
                                            m.update('unit', item['unit']);
                                          }
                                        },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      l.shoppingQtyMeasure,
                      style: AppText.labelLg.copyWith(color: AppColors.text),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsetsDirectional.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.shoppingAmount,
                              style: AppText.bodyLg.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          _StepButton(
                            icon: Icons.remove,
                            onTap: m.busy ? null : () => _step(m, -1),
                          ),
                          SizedBox(
                            width: 64,
                            child: TextFormField(
                              controller: quantity,
                              enabled: !m.busy,
                              textAlign: TextAlign.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: AppText.titleMd.copyWith(
                                color: AppColors.text,
                              ),
                              decoration: const InputDecoration(
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorStyle: TextStyle(fontSize: 0, height: 0),
                                contentPadding: EdgeInsets.zero,
                              ),
                              validator: (v) => shoppingNumber(v, context),
                              onChanged: (v) => m.update('quantity', v),
                            ),
                          ),
                          _StepButton(
                            icon: Icons.add,
                            onTap: m.busy ? null : () => _step(m, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final unit in ['', ...shoppingUnits])
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: _UnitChip(
                                label: unit.isEmpty
                                    ? l.shoppingNoUnit
                                    : shoppingUnitLabel(unit),
                                selected:
                                    (m.fields['unit'] as String? ?? '') == unit,
                                onTap: m.busy
                                    ? null
                                    : () => m.update(
                                        'unit',
                                        unit.isEmpty ? null : unit,
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l.shoppingUrgency,
                      style: AppText.labelLg.copyWith(color: AppColors.text),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final p in TaskPriority.values) ...[
                          if (p != TaskPriority.low) const SizedBox(width: 8),
                          Expanded(
                            child: _UrgencyChip(
                              priority: p,
                              selected: m.fields['priority'] == p.name,
                              onTap: m.busy
                                  ? null
                                  : () => m.update('priority', p.name),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    _LinkCard(
                      m: m,
                      onToggle: (on) async {
                        if (!on) {
                          m.update('linked_inventory_item_id', null);
                          m.update('linked_inventory_name', null);
                          return;
                        }
                        final result =
                            await showModalBottomSheet<Map<String, dynamic>>(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: true,
                              backgroundColor: Colors.white,
                              builder: (_) => const TaskInventoryPicker(),
                            );
                        if (result != null && mounted && m.current) {
                          m.update('linked_inventory_item_id', result['id']);
                          m.update('linked_inventory_name', result['name']);
                          if (result['unit'] != null) {
                            m.update('unit', result['unit']);
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    Text.rich(
                      TextSpan(
                        text: l.shoppingNotes,
                        children: [
                          TextSpan(
                            text: '  (${l.optional})',
                            style: AppText.bodyMd.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      style: AppText.labelLg.copyWith(color: AppColors.text),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: notes,
                      maxLength: 4000,
                      minLines: 1,
                      maxLines: 3,
                      enabled: !m.busy,
                      style: AppText.bodyLg.copyWith(color: AppColors.text),
                      decoration: InputDecoration(
                        counterText: '',
                        suffixIcon: const Icon(
                          Icons.sticky_note_2_outlined,
                          color: AppColors.muted,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => m.update('description', v),
                    ),
                    const SizedBox(height: 16),
                    _AssignRow(
                      members: members,
                      value: m.fields['assigned_to'] as String?,
                      onChanged: m.busy
                          ? null
                          : (v) => m.update('assigned_to', v),
                    ),
                    if (m.error != null) ...[
                      const SizedBox(height: 8),
                      TaskNotice(shoppingError(context, m.error)),
                    ],
                    const SizedBox(height: 16),
                    AppCta(
                      label: m.busy
                          ? l.taskSaving
                          : widget.id == null
                          ? l.shoppingAddToList
                          : l.taskSave,
                      icon: Icons.add_task,
                      color: AppColors.primary,
                      loading: m.busy,
                      onPressed: save,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String shoppingUnitLabel(String unit) => switch (unit) {
  'piece' => 'Pcs',
  'pack' => 'Packs',
  'box' => 'Boxes',
  'bottle' => 'Bottles',
  'roll' => 'Rolls',
  _ => unit,
};

class _SuggestChip extends StatelessWidget {
  const _SuggestChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
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
            color: selected ? Colors.white : AppColors.text,
          ),
        ),
      ),
    ),
  );
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
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
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.sm,
        ),
        child: Icon(icon, color: AppColors.text),
      ),
    ),
  );
}

class _UnitChip extends StatelessWidget {
  const _UnitChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primaryContainer : AppColors.surfaceContainer,
    borderRadius: BorderRadius.circular(9999),
    child: InkWell(
      borderRadius: BorderRadius.circular(9999),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 56),
        alignment: Alignment.center,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        child: Text(
          label,
          style: AppText.labelLg.copyWith(
            color: selected ? Colors.white : AppColors.text,
          ),
        ),
      ),
    ),
  );
}

class _UrgencyChip extends StatelessWidget {
  const _UrgencyChip({
    required this.priority,
    required this.selected,
    required this.onTap,
  });
  final TaskPriority priority;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final dot = switch (priority) {
      TaskPriority.low => const Color(0xFF747686),
      TaskPriority.normal => AppColors.primary,
      TaskPriority.high => const Color(0xFFF2A93B),
      TaskPriority.urgent => AppColors.danger,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected ? AppShadows.md : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? Colors.white : dot,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              taskLabel(context, priority.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.labelLg.copyWith(
                color: selected ? Colors.white : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.m, required this.onToggle});
  final ShoppingFormViewModel m;
  final ValueChanged<bool> onToggle;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final linked = m.fields['linked_inventory_item_id'] != null;
    final name = m.fields['linked_inventory_name'] as String?;
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.link, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.shoppingLinkInventory,
                  style: AppText.titleMd.copyWith(color: AppColors.text),
                ),
              ),
              Switch(
                value: linked,
                onChanged: m.busy ? null : onToggle,
                activeTrackColor: AppColors.secondary,
                activeThumbColor: Colors.white,
                inactiveTrackColor: AppColors.surfaceHighest,
                inactiveThumbColor: Colors.white,
                trackOutlineColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
              ),
            ],
          ),
          if (linked) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsetsDirectional.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const IconTile(
                    icon: Icons.eco_outlined,
                    bg: AppColors.secondaryContainer,
                    fg: AppColors.secondary,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name ?? l.taskLinkedItem,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.labelLg.copyWith(
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          l.shoppingStockHint,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodySm.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l.taskLinkChange,
                    onPressed: m.busy ? null : () => onToggle(true),
                    icon: const Icon(Icons.sync_alt, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssignRow extends StatelessWidget {
  const _AssignRow({
    required this.members,
    required this.value,
    required this.onChanged,
  });
  final List<Map<String, dynamic>> members;
  final String? value;
  final ValueChanged<String?>? onChanged;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final selected = members
        .where((m) => m['user_id'] == value)
        .map((m) => m['display_name'] as String? ?? l.taskFormerMember)
        .firstOrNull;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onChanged == null
          ? null
          : () async {
              final result = await showModalBottomSheet<(String?,)>(
                context: context,
                showDragHandle: true,
                backgroundColor: Colors.white,
                builder: (context) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.groups_outlined),
                        title: Text(l.shoppingFamilyShared),
                        onTap: () => Navigator.pop(context, (null,)),
                      ),
                      for (final member in members)
                        ListTile(
                          leading: InitialsAvatar(
                            member['display_name'] as String? ?? '?',
                            size: 36,
                          ),
                          title: Text(
                            member['display_name'] as String? ??
                                l.taskFormerMember,
                          ),
                          onTap: () => Navigator.pop(context, (
                            member['user_id'] as String,
                          )),
                        ),
                    ],
                  ),
                ),
              );
              if (result != null) onChanged!(result.$1);
            },
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l.shoppingAssignedFor,
                style: AppText.bodyMd.copyWith(color: AppColors.muted),
              ),
            ),
            if (selected != null)
              InitialsAvatar(selected, size: 32)
            else
              const Icon(Icons.groups_outlined, color: AppColors.muted),
            const SizedBox(width: 8),
            Text(
              selected ?? l.shoppingFamilyShared,
              style: AppText.labelLg.copyWith(color: AppColors.text),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
