import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_widgets.dart';
import '../models/household_task.dart';
import '../viewmodels/tasks_view_model.dart';
import '../viewmodels/task_form_view_model.dart';
import '../widgets/task_widgets.dart';
import '../widgets/task_photo_picker.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    this.id,
    this.initialItemId,
    this.initialItemName,
    this.initialType,
    super.key,
  });
  final String? id, initialItemId, initialItemName, initialType;
  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      description = TextEditingController(),
      location = TextEditingController();
  TaskFormViewModel? model;
  @override
  void initState() {
    super.initState();
    Future.microtask(initialize);
  }

  Future<void> initialize() async {
    if (!mounted) return;
    final vm = context.read<TasksViewModel>(),
        scope = context.read<TasksViewModel>().scopeKey;
    await vm.loadMembers();
    if (!mounted || scope != vm.scopeKey) return;
    if (widget.id != null) {
      await vm.open(widget.id!);
      if (!mounted || scope != vm.scopeKey || vm.task == null) return;
    }
    if (widget.id != null && vm.task!.kind == TaskKind.shopping) return;
    model = TaskFormViewModel(
      vm,
      initial: widget.id == null ? null : vm.task,
      initialItemId: widget.initialItemId,
      initialItemName: widget.initialItemName,
      initialType: ['repair', 'chore', 'general'].contains(widget.initialType)
          ? widget.initialType
          : null,
    );
    title.text = model!.fields['title'] as String? ?? '';
    description.text = model!.fields['description'] as String? ?? '';
    location.text = model!.fields['location'] as String? ?? '';
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
    title.dispose();
    description.dispose();
    location.dispose();
    super.dispose();
  }

  void back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('tasks');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy, vm = context.watch<TasksViewModel>(), m = model;
    return AppScaffold(
      title: widget.id == null ? l.taskCreateRequest : l.taskEditRequest,
      bottomNavigationBar: m == null
          ? null
          : SafeArea(
              top: false,
              child: Material(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: m.busy
                            ? null
                            : () async {
                                if (!form.currentState!.validate()) return;
                                final saved = await m.submit();
                                if (!context.mounted || saved == null) return;
                                if (m.errorCode == 'task_saved_photo_failed') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l.taskPhotoPartial)),
                                  );
                                }
                                if (widget.id != null) {
                                  back();
                                } else {
                                  context.pushReplacementNamed(
                                    'taskDetails',
                                    pathParameters: {'id': saved.id},
                                  );
                                }
                              },
                        child: Text(
                          m.uploading
                              ? l.taskUploading
                              : m.busy
                              ? l.taskSaving
                              : l.taskSave,
                        ),
                      ),
                      TextButton(
                        onPressed: m.busy
                            ? null
                            : () async {
                                await vm.clearDraft(m.draftKey, m.originScope);
                                if (mounted) back();
                              },
                        child: Text(l.taskDiscardDraft),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (vm.errorCode != null)
            TaskNotice(taskError(context, vm.errorCode)),
          if (m == null) ...[
            if (vm.detailLoading) const LinearProgressIndicator(),
            if (!vm.detailLoading)
              TextButton(onPressed: back, child: Text(l.taskDismiss)),
          ],
          if (m != null)
            Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TaskNotice(l.taskDraftNote),
                  if (m.restored) TaskNotice(l.taskDraftRestored),
                  Text(
                    l.taskType,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final kind in [
                          TaskKind.shopping,
                          TaskKind.repair,
                          TaskKind.chore,
                          TaskKind.general,
                        ])
                          SizedBox(
                            width: (constraints.maxWidth - 12) / 2,
                            child: _RequestTypeTile(
                              kind: kind,
                              selected: m.fields['task_type'] == kind.name,
                              onTap: m.busy
                                  ? null
                                  : () {
                                      if (kind == TaskKind.shopping) {
                                        context.pushNamed('addShopping');
                                      } else {
                                        m.update('task_type', kind.name);
                                      }
                                    },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TaskSection(
                    children: [
                      TextFormField(
                        controller: title,
                        maxLength: 150,
                        enabled: !m.busy,
                        decoration: InputDecoration(
                          labelText: l.taskTitleField,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? l.taskTitleRequired
                            : null,
                        onChanged: (v) => m.update('title', v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: description,
                        maxLength: 8000,
                        maxLines: 4,
                        enabled: !m.busy,
                        decoration: InputDecoration(
                          labelText: l.taskDescription,
                        ),
                        onChanged: (v) => m.update('description', v),
                      ),
                      const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  TaskSection(
                    title: l.taskAssignee,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          spacing: 12,
                          children: [
                            for (final member in <Map<String, dynamic>>[
                              {
                                'user_id': null,
                                'display_name': l.taskUnassigned,
                              },
                              ...vm.members,
                            ])
                              _AssigneeTile(
                                name:
                                    member['display_name'] as String? ??
                                    l.taskFormerMember,
                                selected:
                                    member['user_id'] ==
                                    m.fields['assigned_to'],
                                onTap: m.busy
                                    ? null
                                    : () => m.update(
                                        'assigned_to',
                                        member['user_id'],
                                      ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TaskSection(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.taskDueDate),
                        subtitle: Text(
                          m.fields['due_date'] as String? ?? l.taskNoDueDate,
                        ),
                        trailing: IconButton(
                          tooltip: l.taskClearDate,
                          onPressed: m.busy
                              ? null
                              : () => m.update('due_date', null),
                          icon: const Icon(Icons.clear),
                        ),
                        onTap: m.busy
                            ? null
                            : () async {
                                final date = await showDatePicker(
                                  context: context,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  initialDate:
                                      DateTime.tryParse(
                                        m.fields['due_date'] as String? ?? '',
                                      ) ??
                                      DateTime.now(),
                                );
                                if (date != null && mounted) {
                                  m.update(
                                    'due_date',
                                    date.toIso8601String().substring(0, 10),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                  if (m.fields['task_type'] == 'repair')
                    TaskSection(
                      tinted: true,
                      title: l.taskRepair,
                      children: [
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: location,
                          maxLength: 150,
                          enabled: !m.busy,
                          decoration: InputDecoration(
                            labelText: l.taskLocation,
                          ),
                          onChanged: (v) => m.update('location', v),
                        ),
                        Card(
                          child: ListTile(
                            title: Text(l.taskLinkedItem),
                            subtitle: Text(
                              m.fields['linked_inventory_name'] as String? ??
                                  l.taskAny,
                            ),
                            trailing: const Icon(Icons.inventory_2_outlined),
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
                                    if (result != null && mounted) {
                                      m.update(
                                        'linked_inventory_item_id',
                                        result['id'],
                                      );
                                      m.update(
                                        'linked_inventory_name',
                                        result['name'],
                                      );
                                    }
                                  },
                          ),
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
                  const SizedBox(height: 16),
                  if (m.photo != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        m.photo!,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Text(l.taskPhotoLimit),
                      ),
                    ),
                    TextButton(
                      onPressed: m.busy ? null : () => m.setPhoto(null),
                      child: Text(l.taskRemovePhoto),
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: m.busy
                        ? null
                        : () async {
                            try {
                              final bytes = await pickTaskPhoto();
                              if (bytes != null && mounted) m.setPhoto(bytes);
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l.taskPhotoLimit)),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(l.taskAddPhoto),
                  ),
                  if (m.errorCode != null)
                    TaskNotice(taskError(context, m.errorCode)),
                  if (m.uploading) const LinearProgressIndicator(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class TaskInventoryPicker extends StatefulWidget {
  const TaskInventoryPicker({super.key});
  @override
  State<TaskInventoryPicker> createState() => _TaskInventoryPickerState();
}

class _TaskInventoryPickerState extends State<TaskInventoryPicker> {
  final search = TextEditingController();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<TasksViewModel>().searchInventory('');
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy, vm = context.watch<TasksViewModel>();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: Column(
            children: [
              Text(
                l.taskChooseItem,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: search,
                decoration: InputDecoration(labelText: l.taskSearchItems),
                onChanged: (v) {
                  timer?.cancel();
                  timer = Timer(const Duration(milliseconds: 350), () {
                    if (mounted) vm.searchInventory(v.trim());
                  });
                },
              ),
              if (vm.pickerLoading) const LinearProgressIndicator(),
              if (vm.errorCode != null)
                TaskNotice(taskError(context, vm.errorCode)),
              Expanded(
                child: ListView(
                  children: [
                    for (final item in vm.candidates)
                      ListTile(
                        title: Text(item['name'] as String),
                        subtitle: Text(item['location'] as String? ?? ''),
                        onTap: () => Navigator.pop(context, item),
                      ),
                    if (!vm.pickerLoading && vm.candidates.isEmpty)
                      TaskNotice(l.taskNoItems),
                    if (vm.candidates.length < vm.candidateTotal)
                      TextButton(
                        onPressed: vm.pickerLoading
                            ? null
                            : () => vm.searchInventory(
                                search.text.trim(),
                                nextPage: true,
                              ),
                        child: Text(l.taskLoadMore),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestTypeTile extends StatelessWidget {
  const _RequestTypeTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });
  final TaskKind kind;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? Theme.of(context).colorScheme.primaryContainer
        : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  taskKindIcon(kind),
                  color: onTap == null
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
                ),
                const Spacer(),
                if (selected)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              taskLabel(context, kind.name),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AssigneeTile extends StatelessWidget {
  const _AssigneeTile({
    required this.name,
    required this.selected,
    required this.onTap,
  });
  final String name;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      width: 80,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
              child: Text(
                name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    ),
  );
}
