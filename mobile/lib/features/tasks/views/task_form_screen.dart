import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/mock_widgets.dart';
import '../../chat/models/chat_task_source.dart';
import '../../chat/viewmodels/family_chat_viewmodel.dart';
import '../../household/viewmodels/session_view_model.dart';
import '../models/household_task.dart';
import '../viewmodels/task_form_view_model.dart';
import '../viewmodels/tasks_view_model.dart';
import '../widgets/task_photo_picker.dart';
import '../widgets/task_widgets.dart';

const _outline = Color(0xFF747686);

/// "Create Request" / "Edit Request" (UI/create_task_household_request).
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    this.id,
    this.initialItemId,
    this.initialItemName,
    this.initialType,
    this.chatSource,
    super.key,
  });
  final String? id, initialItemId, initialItemName, initialType;
  final ChatTaskSource? chatSource;
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
    final source = widget.chatSource;
    final cache = context.read<FamilyChatViewModel>().repository.cache;
    Map<String, dynamic>? secureDraft;
    if (source != null) {
      if (source.household != vm.session.activeHousehold?.id) return;
      try {
        secureDraft = await cache.read(
          vm.session.user!.id,
          source.household,
          'task.${source.messageId}',
        );
      } catch (_) {
        secureDraft = null;
      }
      if (!mounted || scope != vm.scopeKey) return;
    }
    model = TaskFormViewModel(
      vm,
      chatSource: source,
      chatCache: cache,
      secureDraft: secureDraft,
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

  void _setDue(TaskFormViewModel m, DateTime date) =>
      m.update('due_date', date.toIso8601String().substring(0, 10));

  Future<void> _pickDate(TaskFormViewModel m) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate:
          DateTime.tryParse(m.fields['due_date'] as String? ?? '') ??
          DateTime.now(),
    );
    if (date != null && mounted) _setDue(m, date);
  }

  Future<void> _submit(TaskFormViewModel m) async {
    final l = context.taskCopy;
    if (!form.currentState!.validate()) return;
    final saved = await m.submit();
    if (!mounted || saved == null) return;
    if (m.errorCode == 'task_saved_photo_failed') {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.taskPhotoPartial)));
    }
    if (widget.id != null) {
      back();
    } else {
      context.pushReplacementNamed(
        'taskDetails',
        pathParameters: {'id': saved.id},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final vm = context.watch<TasksViewModel>();
    final session = context.watch<SessionViewModel>();
    final m = model;
    return AppScaffold(
      title: widget.id == null ? l.taskCreateRequest : l.taskEditRequest,
      appBar: BrandAppBar(
        title: widget.id == null ? l.taskCreateRequest : l.taskEditRequest,
        showLogo: false,
        onBack: back,
        onProfile: () => context.goNamed('profile'),
        actions: [
          if (m != null)
            PopupMenuButton<String>(
              tooltip: l.taskMoreOptions,
              icon: const Icon(Icons.more_vert, color: AppColors.text),
              onSelected: (_) async {
                await m.discardDraft();
                if (mounted) back();
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
      bottomNavigationBar: m == null
          ? null
          : Container(
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
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: AppCta(
                          label: l.cancel,
                          color: AppColors.surfaceContainer,
                          foreground: AppColors.text,
                          shadow: false,
                          onPressed: m.busy ? null : back,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: AppCta(
                          label: m.uploading
                              ? l.taskUploading
                              : m.busy
                              ? l.taskSaving
                              : widget.id == null
                              ? l.taskCreateRequest
                              : l.taskSave,
                          icon: Icons.send_outlined,
                          color: AppColors.primary,
                          loading: m.busy,
                          onPressed: () => _submit(m),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
        children: [
          if (vm.errorCode != null)
            TaskNotice(taskError(context, vm.errorCode)),
          if (m == null) ...[
            if (vm.detailLoading) const LinearProgressIndicator(minHeight: 2),
            if (!vm.detailLoading)
              TextButton(onPressed: back, child: Text(l.taskDismiss)),
          ],
          if (m != null)
            Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    color: AppColors.primaryFixed.withAlpha(90),
                    shadow: false,
                    radius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                (session.activeHousehold?.name ?? '')
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
                        const SizedBox(height: 4),
                        Text(
                          l.taskFormIntro,
                          style: AppText.bodyMd.copyWith(
                            color: AppColors.text,
                            height: 1.5,
                          ),
                        ),
                        if (m.restored)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(top: 8),
                            child: Text(
                              l.taskDraftRestored,
                              style: AppText.bodySm.copyWith(
                                color: AppColors.primary,
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
                      Flexible(
                        child: Text(
                          l.taskStepKind,
                          style: AppText.headlineSm.copyWith(
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      AppPill(
                        l.taskRequiredTag,
                        bg: AppColors.surfaceContainer,
                        fg: AppColors.primary,
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, box) {
                      final w = (box.maxWidth - 12) / 2;
                      return Wrap(
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
                              width: w,
                              child: _KindTile(
                                kind: kind,
                                selected: m.fields['task_type'] == kind.name,
                                onTap: m.busy
                                    ? null
                                    : () {
                                        if (kind == TaskKind.shopping) {
                                          context.pushNamed(
                                            'addShopping',
                                            extra: widget.chatSource,
                                          );
                                        } else {
                                          m.update('task_type', kind.name);
                                        }
                                      },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    radius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text.rich(
                                TextSpan(
                                  text: l.taskWhatNeeds,
                                  children: [
                                    TextSpan(
                                      text: ' *',
                                      style: AppText.titleMd.copyWith(
                                        color: AppColors.danger,
                                      ),
                                    ),
                                  ],
                                ),
                                style: AppText.titleMd.copyWith(
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            Text(
                              l.taskTapEdit,
                              style: AppText.bodySm.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: title,
                          maxLength: 150,
                          enabled: !m.busy,
                          style: AppText.bodyLg.copyWith(color: AppColors.text),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: l.taskTitleField,
                            suffixIcon: title.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 20,
                                      color: AppColors.muted,
                                    ),
                                    onPressed: m.busy
                                        ? null
                                        : () {
                                            title.clear();
                                            m.update('title', '');
                                          },
                                  ),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? l.taskTitleRequired
                              : null,
                          onChanged: (v) => m.update('title', v),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.taskDescContext,
                          style: AppText.titleMd.copyWith(
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: description,
                          maxLength: 8000,
                          minLines: 4,
                          maxLines: 6,
                          enabled: !m.busy,
                          style: AppText.bodyMd.copyWith(color: AppColors.text),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: l.taskDescription,
                          ),
                          onChanged: (v) => m.update('description', v),
                        ),
                      ],
                    ),
                  ),
                  if (m.fields['task_type'] == 'repair') ...[
                    const SizedBox(height: 16),
                    _RepairCard(
                      m: m,
                      location: location,
                      onPhoto: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final limit = l.taskPhotoLimit;
                        try {
                          final bytes = await pickTaskPhoto();
                          if (bytes != null && mounted) m.setPhoto(bytes);
                        } catch (_) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(limit)),
                          );
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppCard(
                    radius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l.taskPriorityLevel,
                              style: AppText.titleMd.copyWith(
                                color: AppColors.text,
                              ),
                            ),
                            if (m.fields['priority'] == 'urgent')
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.priority_high,
                                    size: 14,
                                    color: AppColors.danger,
                                  ),
                                  Text(
                                    l.taskNeedsFast,
                                    style: AppText.labelMd.copyWith(
                                      color: AppColors.danger,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (final p in TaskPriority.values) ...[
                              if (p != TaskPriority.low)
                                const SizedBox(width: 8),
                              Expanded(
                                child: _PriorityChip(
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AssignCard(m: m, members: vm.members),
                  const SizedBox(height: 16),
                  _DueCard(
                    m: m,
                    onPick: () => _pickDate(m),
                    onSet: (date) => _setDue(m, date),
                  ),
                  if (m.errorCode != null)
                    TaskNotice(taskError(context, m.errorCode)),
                  if (m.uploading) const LinearProgressIndicator(minHeight: 2),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 12),
                    child: Text(
                      l.taskDraftSaved,
                      textAlign: TextAlign.center,
                      style: AppText.bodySm.copyWith(color: AppColors.muted),
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

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });
  final TaskKind kind;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final sub = switch (kind) {
      TaskKind.shopping => l.taskKindShoppingSub,
      TaskKind.repair => l.taskKindRepairSub,
      TaskKind.chore => l.taskKindChoreSub,
      TaskKind.general => l.taskKindGeneralSub,
    };
    return Material(
      color: selected ? AppColors.primaryFixed.withAlpha(120) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsetsDirectional.all(16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryFixed.withAlpha(120)
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
                    icon: taskKindIcon(kind),
                    bg: selected
                        ? AppColors.primary
                        : AppColors.surfaceContainer,
                    fg: selected ? Colors.white : AppColors.text,
                    size: 40,
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
                taskLabel(context, kind.name),
                style: AppText.titleMd.copyWith(
                  color: selected ? AppColors.primary : AppColors.text,
                ),
              ),
              Text(sub, style: AppText.bodySm.copyWith(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepairCard extends StatelessWidget {
  const _RepairCard({
    required this.m,
    required this.location,
    required this.onPhoto,
  });
  final TaskFormViewModel m;
  final TextEditingController location;
  final VoidCallback onPhoto;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final linked = m.fields['linked_inventory_name'] as String?;
    return AppCard(
      color: AppColors.surfaceLow,
      shadow: false,
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
                      Icons.build_circle_outlined,
                      size: 22,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l.taskDiagnostics,
                        style: AppText.titleMd.copyWith(color: AppColors.text),
                      ),
                    ),
                  ],
                ),
              ),
              AppPill(
                l.taskRepairActive,
                bg: AppColors.surfaceContainer,
                fg: AppColors.muted,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l.taskAffected,
            style: AppText.labelMd.copyWith(
              color: AppColors.text,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: location,
            maxLength: 150,
            enabled: !m.busy,
            style: AppText.bodyMd.copyWith(color: AppColors.text),
            decoration: InputDecoration(
              counterText: '',
              hintText: l.taskLocation,
              fillColor: Colors.white,
            ),
            onChanged: (v) => m.update('location', v),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsetsDirectional.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.sm,
            ),
            child: Row(
              children: [
                const IconTile(
                  icon: Icons.inventory_2_outlined,
                  bg: AppColors.surfaceContainer,
                  fg: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    linked == null ? l.taskLinkNone : l.taskLinkPrefix(linked),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyMd.copyWith(
                      color: linked == null
                          ? AppColors.muted
                          : AppColors.secondary,
                    ),
                  ),
                ),
                if (linked != null)
                  IconButton(
                    tooltip: l.taskClearLink,
                    onPressed: m.busy
                        ? null
                        : () {
                            m.update('linked_inventory_item_id', null);
                            m.update('linked_inventory_name', null);
                          },
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ),
                TextButton(
                  onPressed: m.busy
                      ? null
                      : () async {
                          final result =
                              await showModalBottomSheet<Map<String, dynamic>>(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: true,
                                backgroundColor: Colors.white,
                                builder: (_) => const TaskInventoryPicker(),
                              );
                          if (result != null && context.mounted) {
                            m.update('linked_inventory_item_id', result['id']);
                            m.update('linked_inventory_name', result['name']);
                          }
                        },
                  child: Text(
                    l.taskLinkChange,
                    style: AppText.labelMd.copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  l.taskPhotoEvidence,
                  style: AppText.labelMd.copyWith(
                    color: AppColors.text,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Text(
                l.taskPhotoCount(m.photo == null ? 0 : 1),
                style: AppText.bodySm.copyWith(color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (m.photo != null)
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          m.photo!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Text(l.taskPhotoLimit),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: l.taskRemovePhoto,
                            iconSize: 18,
                            onPressed: m.busy ? null : () => m.setPhoto(null),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (m.photo != null) const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: m.busy ? null : onPhoto,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppShadows.sm,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const IconTile(
                          icon: Icons.add_a_photo_outlined,
                          bg: AppColors.surfaceContainer,
                          fg: AppColors.primary,
                          size: 40,
                          radius: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.taskAddPhotoShort,
                          style: AppText.labelMd.copyWith(
                            color: AppColors.text,
                            letterSpacing: 0,
                          ),
                        ),
                        Text(
                          l.taskMaxSize,
                          style: AppText.labelSm.copyWith(
                            color: AppColors.muted,
                            letterSpacing: 0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.priority,
    required this.selected,
    required this.onTap,
  });
  final TaskPriority priority;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final (dot, bg, fg) = switch (priority) {
      TaskPriority.low => (
        const Color(0xFF747686),
        AppColors.surfaceContainer,
        AppColors.text,
      ),
      TaskPriority.normal => (
        AppColors.primary,
        AppColors.surfaceContainer,
        AppColors.text,
      ),
      TaskPriority.high => (
        const Color(0xFFF2A93B),
        AppColors.surfaceContainer,
        AppColors.text,
      ),
      TaskPriority.urgent => (
        AppColors.danger,
        const Color(0xFFFFDAD6),
        AppColors.danger,
      ),
    };
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: dot, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (priority == TaskPriority.urgent)
              Icon(Icons.bolt, size: 16, color: dot)
            else
              SizedBox.square(
                dimension: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
              ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                taskLabel(context, priority.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.labelMd.copyWith(color: fg, letterSpacing: 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignCard extends StatelessWidget {
  const _AssignCard({required this.m, required this.members});
  final TaskFormViewModel m;
  final List<Map<String, dynamic>> members;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final selected = m.fields['assigned_to'];
    return AppCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.taskAssignResp,
                      style: AppText.titleMd.copyWith(color: AppColors.text),
                    ),
                    Text(
                      l.taskWhoHandles,
                      style: AppText.bodySm.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Text(
                l.taskSelectedCount(selected == null ? 0 : 1),
                style: AppText.labelMd.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _AssigneeTile(
                  name: l.taskAnyone,
                  anyone: true,
                  selected: selected == null,
                  onTap: m.busy ? null : () => m.update('assigned_to', null),
                ),
                for (final member in members)
                  _AssigneeTile(
                    name:
                        (member['display_name'] as String?) ??
                        l.taskFormerMember,
                    selected: member['user_id'] == selected,
                    onTap: m.busy
                        ? null
                        : () => m.update('assigned_to', member['user_id']),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssigneeTile extends StatelessWidget {
  const _AssigneeTile({
    required this.name,
    required this.selected,
    required this.onTap,
    this.anyone = false,
  });
  final String name;
  final bool selected;
  final VoidCallback? onTap;
  final bool anyone;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = taskAvatarColors(name);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsetsDirectional.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: anyone
                      ? const DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_off_outlined,
                            color: AppColors.muted,
                          ),
                        )
                      : InitialsAvatar(name, size: 48, bg: bg, fg: fg),
                ),
                if (selected)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.labelMd.copyWith(
                color: selected ? AppColors.primary : AppColors.muted,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueCard extends StatelessWidget {
  const _DueCard({required this.m, required this.onPick, required this.onSet});
  final TaskFormViewModel m;
  final VoidCallback onPick;
  final ValueChanged<DateTime> onSet;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final value = m.fields['due_date'] as String?;
    final date = DateTime.tryParse(value ?? '');
    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final weekend = today.add(
      Duration(days: (DateTime.saturday - today.weekday + 7) % 7),
    );
    bool is_(DateTime d) => date != null && DateUtils.isSameDay(date, d);
    return AppCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.taskTargetCompletion,
            style: AppText.titleMd.copyWith(color: AppColors.text),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: m.busy ? null : onPick,
            child: Container(
              padding: const EdgeInsetsDirectional.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const IconTile(
                    icon: Icons.calendar_today_outlined,
                    bg: AppColors.primary,
                    fg: Colors.white,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      date == null
                          ? l.taskNoDueDate
                          : taskDueText(context, l, value!),
                      style: AppText.titleMd.copyWith(color: AppColors.text),
                    ),
                  ),
                  if (date != null)
                    IconButton(
                      tooltip: l.taskClearDate,
                      onPressed: m.busy
                          ? null
                          : () => m.update('due_date', null),
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.muted,
                      ),
                    ),
                  const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickDate(
                  label: l.taskToday,
                  selected: is_(today),
                  onTap: m.busy ? null : () => onSet(today),
                ),
                _QuickDate(
                  label: l.taskTomorrow,
                  selected: is_(tomorrow),
                  onTap: m.busy ? null : () => onSet(tomorrow),
                ),
                _QuickDate(
                  label: l.taskThisWeekend,
                  selected: is_(weekend) && !is_(today) && !is_(tomorrow),
                  onTap: m.busy ? null : () => onSet(weekend),
                ),
                _QuickDate(
                  label: l.taskPickDate,
                  icon: Icons.calendar_month_outlined,
                  selected: false,
                  onTap: m.busy ? null : onPick,
                ),
              ],
            ),
          ),
          if (date != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8),
              child: Text(
                DateFormat.yMMMEd(Localizations.localeOf(context).languageCode)
                    .format(date),
                style: AppText.bodySm.copyWith(color: _outline),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickDate extends StatelessWidget {
  const _QuickDate({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: Material(
      color: selected ? AppColors.primary : AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.muted),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppText.labelMd.copyWith(
                  color: selected ? Colors.white : AppColors.muted,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
            0,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.taskChooseItem,
                style: AppText.headlineSm.copyWith(color: AppColors.text),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: search,
                decoration: InputDecoration(
                  hintText: l.taskSearchItems,
                  prefixIcon: const Icon(Icons.search, color: _outline),
                ),
                onChanged: (v) {
                  timer?.cancel();
                  timer = Timer(const Duration(milliseconds: 350), () {
                    if (mounted) vm.searchInventory(v.trim());
                  });
                },
              ),
              if (vm.pickerLoading) const LinearProgressIndicator(minHeight: 2),
              if (vm.errorCode != null)
                TaskNotice(taskError(context, vm.errorCode)),
              Expanded(
                child: ListView(
                  children: [
                    for (final item in vm.candidates)
                      ListTile(
                        leading: const IconTile(
                          icon: Icons.inventory_2_outlined,
                          bg: AppColors.surfaceContainer,
                          fg: AppColors.primary,
                        ),
                        title: Text(
                          item['name'] as String,
                          style: AppText.titleMd.copyWith(
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: Text(
                          item['location'] as String? ?? '',
                          style: AppText.bodySm.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
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
