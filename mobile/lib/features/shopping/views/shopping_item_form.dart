import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../tasks/models/household_task.dart';
import '../../tasks/viewmodels/tasks_view_model.dart';
import '../../tasks/views/task_form_screen.dart';
import '../../tasks/widgets/task_widgets.dart';
import '../viewmodels/shopping_list_viewmodel.dart';
import '../viewmodels/shopping_form_viewmodel.dart';
import '../widgets/shopping_widgets.dart';

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
  const ShoppingItemForm({this.id, this.prefill = const {}, super.key});
  final String? id;
  final Map<String, dynamic> prefill;
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
    final item = widget.id == null ? null : await vm.open(widget.id!);
    if (!mounted ||
        !vm.current(captured) ||
        (widget.id != null && item == null)) {
      return;
    }
    model = ShoppingFormViewModel(vm, initial: item, prefill: widget.prefill);
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

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy,
        m = model,
        vm = context.watch<ShoppingListViewModel>(),
        members = context.watch<TasksViewModel>().members;
    return AppScaffold(
      title: widget.id == null ? l.shoppingAdd : l.taskEdit,
      bottomNavigationBar: m == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: m.busy ? null : save,
                  child: Text(
                    m.busy
                        ? l.taskSaving
                        : widget.id == null
                        ? l.shoppingAddToList
                        : l.taskSave,
                  ),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (vm.error != null) TaskNotice(shoppingError(context, vm.error)),
          if (m == null) const LinearProgressIndicator(),
          if (m != null)
            Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    vm.session.activeHousehold?.name ?? '',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.shoppingQuickAdd,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  TaskNotice(
                    m.restored ? l.taskDraftRestored : l.shoppingDraftNote,
                  ),
                  TaskSection(
                    children: [
                      TextFormField(
                        controller: name,
                        maxLength: 150,
                        enabled: !m.busy,
                        decoration: InputDecoration(labelText: l.shoppingName),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? l.taskTitleRequired
                            : null,
                        onChanged: (v) => m.update('title', v),
                      ),
                    ],
                  ),
                  TaskSection(
                    title: l.shoppingQuantity,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: quantity,
                              enabled: !m.busy,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: l.shoppingQuantity,
                              ),
                              validator: (v) => shoppingNumber(v, context),
                              onChanged: (v) => m.update('quantity', v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: taskDropdown(
                              l.shoppingUnit,
                              m.fields['unit'] as String? ?? '',
                              [
                                ('', l.shoppingNoUnit),
                                for (final unit in shoppingUnits) (unit, unit),
                              ],
                              m.busy
                                  ? null
                                  : (v) => m.update('unit', v == '' ? null : v),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  TaskSection(
                    title: l.taskPriority,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final priority in TaskPriority.values)
                            ChoiceChip(
                              label: Text(taskLabel(context, priority.name)),
                              selected: m.fields['priority'] == priority.name,
                              onSelected: m.busy
                                  ? null
                                  : (_) => m.update('priority', priority.name),
                            ),
                        ],
                      ),
                    ],
                  ),
                  TaskSection(
                    tinted: true,
                    title: l.taskLinkedItem,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.link),
                        title: Text(
                          m.fields['linked_inventory_name'] as String? ??
                              l.taskChooseItem,
                        ),
                        onTap: m.busy
                            ? null
                            : () async {
                                final result =
                                    await showModalBottomSheet<
                                      Map<String, dynamic>
                                    >(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) =>
                                          const TaskInventoryPicker(),
                                    );
                                if (result != null && mounted && m.current) {
                                  m.update(
                                    'linked_inventory_item_id',
                                    result['id'],
                                  );
                                  m.update(
                                    'linked_inventory_name',
                                    result['name'],
                                  );
                                  if (result['unit'] != null) {
                                    m.update('unit', result['unit']);
                                  }
                                }
                              },
                      ),
                      if (m.fields['linked_inventory_item_id'] != null)
                        TextButton(
                          onPressed: m.busy
                              ? null
                              : () {
                                  m.update('linked_inventory_item_id', null);
                                  m.update('linked_inventory_name', null);
                                },
                          child: Text(l.taskClearLink),
                        ),
                    ],
                  ),
                  TaskSection(
                    children: [
                      TextFormField(
                        controller: notes,
                        maxLength: 4000,
                        maxLines: 3,
                        enabled: !m.busy,
                        decoration: InputDecoration(labelText: l.shoppingNotes),
                        onChanged: (v) => m.update('description', v),
                      ),
                      const SizedBox(height: 16),
                      AssigneeSelector(
                        members: members,
                        value: m.fields['assigned_to'] as String?,
                        onChanged: m.busy
                            ? null
                            : (v) => m.update('assigned_to', v),
                      ),
                    ],
                  ),
                  if (m.error != null)
                    TaskNotice(shoppingError(context, m.error)),
                  TextButton(
                    onPressed: m.busy
                        ? null
                        : () async {
                            await vm.clearDraft(m.draftKey, m.originScope);
                            if (context.mounted) context.pop();
                          },
                    child: Text(l.taskDiscardDraft),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
