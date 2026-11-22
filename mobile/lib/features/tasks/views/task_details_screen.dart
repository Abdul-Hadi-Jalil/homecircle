import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/mock_widgets.dart';
import '../../household/viewmodels/session_view_model.dart';
import '../models/household_task.dart';
import '../models/task_activity.dart';
import '../models/task_comment.dart';
import '../viewmodels/tasks_view_model.dart';
import '../widgets/task_photo_picker.dart';
import '../widgets/task_widgets.dart';

const _outline = Color(0xFF747686);

/// "Task Details" screen (UI/task_repair_details).
class TaskDetailsScreen extends StatefulWidget {
  const TaskDetailsScreen({required this.id, super.key});
  final String id;
  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final composer = TextEditingController();
  String scope = '';
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final vm = context.read<TasksViewModel>();
      scope = vm.scopeKey;
      composer.text =
          vm.draft('comment.${widget.id}')?['body'] as String? ?? '';
      vm.loadMembers();
      await vm.open(widget.id);
      if (mounted &&
          scope == vm.scopeKey &&
          vm.task?.kind == TaskKind.shopping) {
        context.pushReplacementNamed(
          'shoppingDetails',
          pathParameters: {'id': widget.id},
        );
      }
    });
  }

  @override
  void dispose() {
    composer.dispose();
    super.dispose();
  }

  Future<void> refresh(TasksViewModel vm, {bool force = false}) async {
    if (mounted &&
        scope == vm.scopeKey &&
        (force || vm.task?.id == widget.id)) {
      await vm.open(widget.id);
    }
  }

  Future<void> complete(TasksViewModel vm, HouseholdTask selected) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const _TaskTextDialog(completion: true),
    );
    if (note == null || !mounted) return;
    final result = await vm.setStatus(
      selected,
      TaskStatus.completed,
      note: note.trim().isEmpty ? null : note.trim(),
    );
    if (result == null || !mounted) return;
    await refresh(vm);
    if (!mounted || !result.linkedDurable || result.linkedItemId == null) {
      return;
    }
    final l = context.taskCopy;
    final change = await showConfirmDialog(
      context,
      title: l.taskConditionQuestion,
      message: l.taskConditionHelp,
      confirmLabel: l.taskMarkWorking,
      cancelLabel: l.taskKeepCondition,
      icon: Icons.build_circle_outlined,
    );
    if (change == true && mounted) {
      final updated = await vm.markLinkedWorking(result);
      if (!updated && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.taskConditionFailed)));
      }
    }
  }

  Future<void> assign(TasksViewModel vm, HouseholdTask selected) async {
    final l = context.taskCopy;
    final result = await showMemberSheet(
      context,
      title: l.assignSheetTitle,
      members: vm.members,
      current: selected.assignedTo,
      unassignedLabel: l.taskUnassigned,
      unassignedSub: l.unassignedPool,
      resetLabel: l.resetLabel,
      applyLabel: l.applySelection,
      selectedLabel: l.assignedCount(selected.assignedTo == null ? 0 : 1),
      roleLabel: (m) => m['role'] == 'admin' ? l.adminRole : l.memberRole,
      fallbackName: l.taskFormerMember,
    );
    if (result != null &&
        mounted &&
        result.$1 != selected.assignedTo &&
        await vm.assign(
              selected,
              result.$1 == null ? 'unassign' : 'assign',
              result.$1,
            ) !=
            null) {
      await refresh(vm);
    }
  }

  Future<void> photo(
    TasksViewModel vm,
    HouseholdTask selected, {
    String? commentId,
  }) async {
    final l = context.taskCopy;
    try {
      final bytes = await pickTaskPhoto();
      if (bytes == null || !mounted || vm.task?.id != widget.id) return;
      if (await vm.upload(selected, bytes, commentId: commentId) != null) {
        await refresh(vm);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.taskPhotoLimit)));
      }
    }
  }

  Future<void> _setStatus(
    TasksViewModel vm,
    HouseholdTask selected,
    TaskStatus status,
  ) async {
    if (status == selected.status) return;
    if (status == TaskStatus.completed) {
      await complete(vm, selected);
    } else if (await vm.setStatus(selected, status) != null) {
      await refresh(vm);
    }
  }

  Future<void> _menu(
    String value,
    TasksViewModel vm,
    HouseholdTask selected,
  ) async {
    final l = context.taskCopy;
    switch (value) {
      case 'refresh':
        await vm.open(widget.id);
      case 'edit':
        await context.pushNamed(
          'editTask',
          pathParameters: {'id': selected.id},
        );
        if (mounted) await refresh(vm, force: true);
      case 'cancel':
        if (await confirmTask(context, l.taskCancel) &&
            mounted &&
            await vm.setStatus(selected, TaskStatus.cancelled) != null) {
          await refresh(vm);
        }
      case 'archive':
        if (await confirmTask(
              context,
              selected.archived ? l.taskRestoreQuestion : l.taskArchiveQuestion,
              message: selected.archived ? null : l.taskArchiveHelp,
            ) &&
            mounted &&
            await vm.archive(selected) != null) {
          await refresh(vm);
        }
      default:
        if (value.startsWith('priority:')) {
          final priority = TaskPriority.values.byName(value.substring(9));
          if (await vm.setPriority(selected, priority) != null) {
            await refresh(vm);
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final vm = context.watch<TasksViewModel>();
    final selected = vm.task;
    final ready = selected != null && selected.id == widget.id;
    final locked = vm.busy || vm.cached;
    final editable =
        ready && !selected.archived && selected.kind != TaskKind.shopping;
    return AppScaffold(
      title: l.taskDetailsTitle,
      appBar: BrandAppBar(
        title: l.taskDetailsTitle,
        showLogo: false,
        onBack: () =>
            context.canPop() ? context.pop() : context.goNamed('tasks'),
        onProfile: () => context.goNamed('profile'),
        actions: [
          if (ready)
            PopupMenuButton<String>(
              tooltip: l.taskMoreOptions,
              enabled: !locked,
              icon: const Icon(Icons.more_vert, color: AppColors.text),
              onSelected: (value) => _menu(value, vm, selected),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'refresh', child: Text(l.taskRefresh)),
                if (editable)
                  PopupMenuItem(value: 'edit', child: Text(l.taskEdit)),
                if (editable)
                  for (final p in TaskPriority.values)
                    if (p != selected.priority)
                      PopupMenuItem(
                        value: 'priority:${p.name}',
                        child: Text(
                          '${l.taskChangePriority}: ${taskLabel(context, p.name)}',
                        ),
                      ),
                if (editable && !selected.terminal)
                  PopupMenuItem(value: 'cancel', child: Text(l.taskCancel)),
                if (selected.kind != TaskKind.shopping)
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(
                      selected.archived ? l.taskRestore : l.taskArchive,
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
        children: [
          if (vm.errorCode != null)
            TaskNotice(taskError(context, vm.errorCode)),
          if (vm.cached) TaskNotice(l.taskCached),
          if (vm.detailLoading) const LinearProgressIndicator(minHeight: 2),
          if (ready) ...[
            _Breadcrumb(task: selected),
            const SizedBox(height: 12),
            _HeaderCard(
              task: selected,
              photos: [
                for (final a in vm.attachments.where(
                  (a) => a.commentId == null,
                ))
                  _TaskPhoto(attachment: a, task: selected),
              ],
              addPhoto: editable
                  ? TextButton.icon(
                      onPressed: locked ? null : () => photo(vm, selected),
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: Text(l.taskAddPhoto),
                    )
                  : null,
              more: vm.more('attachments')
                  ? TextButton(
                      onPressed: vm.sectionBusy('attachments')
                          ? null
                          : () => vm.loadSection('attachments'),
                      child: Text(l.taskLoadMore),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            _DetailsCard(
              task: selected,
              onReassign: editable && !locked
                  ? () => assign(vm, selected)
                  : null,
            ),
            if (selected.linkedItemId != null) ...[
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const IconTile(
                      icon: Icons.inventory_2_outlined,
                      bg: AppColors.surfaceContainer,
                      fg: AppColors.primary,
                    ),
                    title: Text(
                      l.taskLinkedItem,
                      style: AppText.labelMd.copyWith(color: AppColors.muted),
                    ),
                    subtitle: Text(
                      selected.linkedItemName ?? l.taskLinkedItem,
                      style: AppText.titleMd.copyWith(color: AppColors.text),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: _outline),
                    onTap: () async {
                      await context.pushNamed(
                        'inventoryDetails',
                        pathParameters: {'id': selected.linkedItemId!},
                      );
                      if (mounted) await refresh(vm, force: true);
                    },
                  ),
                ),
              ),
            ],
            if (selected.data['completion_note'] != null) ...[
              const SizedBox(height: 16),
              AppCard(
                color: AppColors.secondaryContainer.withAlpha(90),
                shadow: false,
                child: Text(
                  '${l.taskCompletionHistory}: ${selected.data['completion_note']}',
                  style: AppText.bodyMd.copyWith(color: AppColors.text),
                ),
              ),
            ],
            if (vm.busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
              Text(l.taskSaving),
            ],
            if (!selected.archived && selected.kind != TaskKind.shopping) ...[
              const SizedBox(height: 16),
              _ProgressCard(
                task: selected,
                locked: locked,
                synced: !vm.cached,
                onStatus: (status) => _setStatus(vm, selected, status),
                onComplete: () => complete(vm, selected),
                onTake: () async {
                  if (await vm.assign(selected, 'claim', null) != null) {
                    await refresh(vm);
                  }
                },
                onReopen: () async {
                  if (await confirmTask(
                        context,
                        l.taskReopen,
                        message: l.taskReopenedHelp,
                      ) &&
                      mounted &&
                      await vm.setStatus(
                            selected,
                            TaskStatus.open,
                            reopen: true,
                          ) !=
                          null) {
                    await refresh(vm);
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            _DiscussionCard(
              task: selected,
              vm: vm,
              composer: composer,
              locked: locked,
              scope: scope,
              taskId: widget.id,
              onChanged: (text) =>
                  vm.saveDraft('comment.${widget.id}', {'body': text}, scope),
              onPhoto: ({String? commentId}) =>
                  photo(vm, selected, commentId: commentId),
              onRefresh: () => refresh(vm),
            ),
            const SizedBox(height: 16),
            _ActivityCard(vm: vm),
          ],
        ],
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.task});
  final HouseholdTask task;
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final l = context.taskCopy;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            children: [
              const Icon(
                Icons.home_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${session.activeHousehold?.name ?? ''} • ${taskLabel(context, task.kind.name)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelMd.copyWith(
                    color: AppColors.muted,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        AppPill(
          '#${(task.id.length > 6 ? task.id.substring(0, 6) : task.id).toUpperCase()}',
          bg: AppColors.surfaceContainer,
          fg: AppColors.muted,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 8,
            vertical: 2,
          ),
          style: AppText.labelSm.copyWith(letterSpacing: 0.3),
        ),
        if (task.archived) ...[
          const SizedBox(width: 6),
          AppPill(
            l.taskArchived,
            bg: AppColors.surfaceHighest,
            fg: AppColors.muted,
          ),
        ],
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.task,
    required this.photos,
    this.addPhoto,
    this.more,
  });
  final HouseholdTask task;
  final List<Widget> photos;
  final Widget? addPhoto;
  final Widget? more;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 20,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  AppPill(
                    taskLabel(context, task.kind.name),
                    icon: taskKindIcon(task.kind),
                    bg: AppColors.surfaceContainer,
                    fg: AppColors.text,
                  ),
                  PriorityBadge(task.priority),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(task.status),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          task.title,
          style: AppText.headlineLg.copyWith(
            color: AppColors.text,
            letterSpacing: -0.65,
          ),
        ),
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            task.description,
            style: AppText.bodyMd.copyWith(color: AppColors.muted, height: 1.5),
          ),
        ],
        for (final photo in photos) ...[const SizedBox(height: 12), photo],
        ?addPhoto,
        ?more,
      ],
    ),
  );
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.task, required this.onReassign});
  final HouseholdTask task;
  final VoidCallback? onReassign;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final creator = task.creatorName?.trim();
    final assignee = task.assigneeName?.trim();
    final created = DateTime.tryParse('${task.data['created_at'] ?? ''}');
    final urgent = task.priority == TaskPriority.urgent || task.overdue();
    final location = task.data['location'] as String?;
    final creatorName = creator != null && creator.isNotEmpty
        ? creator
        : l.taskFormerMember;
    final assigneeName = assignee != null && assignee.isNotEmpty
        ? assignee
        : task.assignedTo == null
        ? l.taskUnassigned
        : l.taskFormerMember;
    return AppCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                l.taskDetailsHeading,
                style: AppText.titleMd.copyWith(color: AppColors.text),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final w = (box.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: w,
                    child: _Cell(
                      label: l.taskCellReported,
                      leading: InitialsAvatar(
                        creatorName,
                        size: 28,
                        bg: AppColors.primaryFixed,
                        fg: AppColors.onPrimaryFixed,
                      ),
                      value: creatorName,
                      sub: created == null
                          ? null
                          : DateFormat.MMMd().add_jm().format(
                              created.toLocal(),
                            ),
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onReassign,
                      child: _Cell(
                        label: l.taskCellAssigned,
                        trailing: onReassign == null
                            ? null
                            : const Icon(
                                Icons.swap_horiz,
                                size: 18,
                                color: AppColors.primary,
                              ),
                        leading: InitialsAvatar(
                          assigneeName,
                          size: 28,
                          bg: AppColors.tertiaryFixed,
                          fg: AppColors.onTertiaryFixed,
                        ),
                        value: assigneeName,
                        sub: onReassign == null
                            ? null
                            : (task.assignedTo == null
                                  ? l.taskTapAssign
                                  : l.taskTapReassign),
                        subColor: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _Cell(
                      label: l.taskCellDue,
                      leading: Icon(
                        urgent ? Icons.alarm : Icons.calendar_today_outlined,
                        size: 24,
                        color: urgent ? AppColors.danger : AppColors.muted,
                      ),
                      value: task.dueDate == null
                          ? l.taskNoDueDate
                          : taskDueText(context, l, task.dueDate!),
                      valueColor: urgent ? AppColors.danger : null,
                      sub: task.overdue()
                          ? l.taskOverdue
                          : task.priority == TaskPriority.urgent
                          ? l.taskUrgentTurnaround
                          : null,
                      subColor: AppColors.danger,
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _Cell(
                      label: l.taskCellLocation,
                      leading: const Icon(
                        Icons.location_on_outlined,
                        size: 24,
                        color: AppColors.secondary,
                      ),
                      value: location == null || location.isEmpty
                          ? l.taskLocationNone
                          : location,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.value,
    this.leading,
    this.trailing,
    this.sub,
    this.subColor,
    this.valueColor,
  });
  final String label;
  final String value;
  final Widget? leading;
  final Widget? trailing;
  final String? sub;
  final Color? subColor;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.all(12),
    decoration: BoxDecoration(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.labelSm.copyWith(color: AppColors.muted),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: AppText.labelLg.copyWith(
                      color: valueColor ?? AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub!,
                      style: AppText.bodySm.copyWith(
                        color: subColor ?? AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.task,
    required this.locked,
    required this.synced,
    required this.onStatus,
    required this.onComplete,
    required this.onTake,
    required this.onReopen,
  });
  final HouseholdTask task;
  final bool locked;
  final bool synced;
  final ValueChanged<TaskStatus> onStatus;
  final VoidCallback onComplete;
  final VoidCallback onTake;
  final VoidCallback onReopen;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final segments = [
      (TaskStatus.open, taskLabel(context, 'open')),
      (TaskStatus.inProgress, l.taskSegProgress),
      (TaskStatus.blocked, taskLabel(context, 'blocked')),
      (TaskStatus.completed, l.taskSegDone),
    ];
    return AppCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  l.taskProgressState,
                  style: AppText.labelMd.copyWith(
                    color: AppColors.muted,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: synced ? AppColors.secondary : AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    synced ? l.taskSynchronized : l.taskOfflineShort,
                    style: AppText.labelSm.copyWith(
                      color: synced ? AppColors.secondary : AppColors.danger,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ],
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
                for (final segment in segments)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: locked || task.terminal
                          ? null
                          : () => onStatus(segment.$1),
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: task.status == segment.$1
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          segment.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.labelMd.copyWith(
                            letterSpacing: 0,
                            color: task.status == segment.$1
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
          const SizedBox(height: 16),
          if (task.terminal)
            AppCta(
              label: l.taskReopen,
              icon: Icons.restart_alt,
              color: AppColors.primary,
              onPressed: locked ? null : onReopen,
            )
          else ...[
            AppCta(
              label: l.taskMarkCompleted,
              icon: Icons.check_circle_outline,
              color: AppColors.primary,
              onPressed: locked ? null : onComplete,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l.taskNotifyHint,
                    style: AppText.bodySm.copyWith(color: AppColors.muted),
                  ),
                ),
                if (task.assignedTo == null)
                  Flexible(
                    child: TextButton.icon(
                      onPressed: locked ? null : onTake,
                      icon: const Icon(Icons.person_add_alt, size: 18),
                      label: Text(
                        l.taskTakeOwnership,
                        textAlign: TextAlign.center,
                        style: AppText.labelSm.copyWith(
                          color: AppColors.primary,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscussionCard extends StatelessWidget {
  const _DiscussionCard({
    required this.task,
    required this.vm,
    required this.composer,
    required this.locked,
    required this.scope,
    required this.taskId,
    required this.onChanged,
    required this.onPhoto,
    required this.onRefresh,
  });
  final HouseholdTask task;
  final TasksViewModel vm;
  final TextEditingController composer;
  final bool locked;
  final String scope;
  final String taskId;
  final ValueChanged<String> onChanged;
  final Future<void> Function({String? commentId}) onPhoto;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final canWrite = !task.archived && task.kind != TaskKind.shopping;
    return AppCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l.taskDiscussion,
                      style: AppText.headlineSm.copyWith(color: AppColors.text),
                    ),
                    AppPill(
                      l.taskCommentCount(vm.comments.length),
                      bg: AppColors.primaryFixed,
                      fg: AppColors.primary,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.lock_outline, size: 14, color: _outline),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l.taskSharedWithHousehold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(color: AppColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (vm.comments.isEmpty)
            Text(
              l.taskNoComments,
              style: AppText.bodyMd.copyWith(color: AppColors.muted),
            ),
          for (final comment in vm.comments)
            _CommentRow(
              comment: comment,
              task: task,
              vm: vm,
              locked: locked,
              onPhoto: onPhoto,
              onRefresh: onRefresh,
            ),
          if (vm.more('comments'))
            TextButton(
              onPressed: vm.sectionBusy('comments')
                  ? null
                  : () => vm.loadSection('comments'),
              child: Text(l.taskLoadMore),
            ),
          if (canWrite) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 6, 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l.taskAddPhoto,
                    onPressed: locked ? null : () => onPhoto(),
                    icon: const Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.muted,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: composer,
                      maxLength: 4000,
                      minLines: 1,
                      maxLines: 3,
                      enabled: !vm.busy,
                      style: AppText.bodyMd.copyWith(color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: l.taskWriteUpdate,
                        hintStyle: AppText.bodyMd.copyWith(color: _outline),
                        counterText: '',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: onChanged,
                    ),
                  ),
                  Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: l.taskSendComment,
                      onPressed: locked
                          ? null
                          : () async {
                              if (composer.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l.taskCommentRequired),
                                  ),
                                );
                                return;
                              }
                              final posted = await vm.addComment(
                                task,
                                composer.text.trim(),
                              );
                              if (posted == null || !context.mounted) return;
                              composer.clear();
                              await vm.clearDraft('comment.$taskId', scope);
                              await onRefresh();
                            },
                      icon: const Icon(
                        Icons.arrow_upward,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
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

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.task,
    required this.vm,
    required this.locked,
    required this.onPhoto,
    required this.onRefresh,
  });
  final TaskComment comment;
  final HouseholdTask task;
  final TasksViewModel vm;
  final bool locked;
  final Future<void> Function({String? commentId}) onPhoto;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final name = comment.authorName?.isNotEmpty == true
        ? comment.authorName!
        : l.taskFormerMember;
    final mine = vm.canChangeComment(comment);
    final (avBg, avFg) = taskAvatarColors(name);
    final when = DateTime.tryParse('${comment.data['updated_at'] ?? ''}');
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(name, size: 32, bg: avBg, fg: avFg),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: AppText.labelMd.copyWith(
                          color: AppColors.text,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (when != null)
                          Text(
                            DateFormat.jm().format(when.toLocal()),
                            style: AppText.bodySm.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        if (!task.archived && mine)
                          PopupMenuButton<String>(
                            tooltip: l.taskMoreOptions,
                            enabled: !locked,
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            icon: const Icon(
                              Icons.more_horiz,
                              size: 18,
                              color: AppColors.muted,
                            ),
                            onSelected: (value) async {
                              if (value == 'edit') {
                                final text = await showDialog<String>(
                                  context: context,
                                  builder: (_) =>
                                      _TaskTextDialog(initial: comment.body),
                                );
                                if (text != null &&
                                    context.mounted &&
                                    await vm.editComment(task, comment, text) !=
                                        null) {
                                  await onRefresh();
                                }
                              } else if (value == 'delete') {
                                if (await confirmTask(
                                      context,
                                      l.taskDeleteCommentQuestion,
                                    ) &&
                                    context.mounted &&
                                    await vm.deleteComment(task, comment) !=
                                        null) {
                                  await onRefresh();
                                }
                              } else {
                                await onPhoto(commentId: comment.id);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(l.taskEditComment),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(l.taskDeleteComment),
                              ),
                              PopupMenuItem(
                                value: 'photo',
                                child: Text(l.taskCommentPhoto),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsetsDirectional.all(12),
                  decoration: BoxDecoration(
                    color: mine
                        ? AppColors.surfaceContainer
                        : AppColors.surfaceLow,
                    borderRadius: const BorderRadiusDirectional.only(
                      topEnd: Radius.circular(12),
                      bottomStart: Radius.circular(12),
                      bottomEnd: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    comment.body,
                    style: AppText.bodyMd.copyWith(color: AppColors.text),
                  ),
                ),
                for (final attachment in vm.attachments.where(
                  (a) => a.commentId == comment.id,
                ))
                  _TaskPhoto(attachment: attachment, task: task),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.vm});
  final TasksViewModel vm;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        type: MaterialType.transparency,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
            childrenPadding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 12),
            leading: const Icon(Icons.history, color: AppColors.muted),
            title: Text(
              l.taskActivityLog,
              style: AppText.headlineSm.copyWith(color: AppColors.text),
            ),
            trailing: Text(
              l.taskEventCount(vm.activity.length),
              style: AppText.labelMd.copyWith(
                color: AppColors.muted,
                letterSpacing: 0,
              ),
            ),
            children: [
              if (vm.activity.isEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l.taskNoActivity),
                ),
              for (final event in vm.activity) _TaskActivityTile(event),
              if (vm.more('activity'))
                TextButton(
                  onPressed: vm.sectionBusy('activity')
                      ? null
                      : () => vm.loadSection('activity'),
                  child: Text(l.taskLoadMore),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskTextDialog extends StatefulWidget {
  const _TaskTextDialog({this.initial = '', this.completion = false});
  final String initial;
  final bool completion;
  @override
  State<_TaskTextDialog> createState() => _TaskTextDialogState();
}

class _TaskTextDialogState extends State<_TaskTextDialog> {
  late final text = TextEditingController(text: widget.initial);
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    return AppDialogFrame(
      title: widget.completion ? l.taskCompletionNote : l.taskEditComment,
      icon: widget.completion ? Icons.task_alt : Icons.edit_outlined,
      iconBg: AppColors.primaryFixed,
      iconFg: AppColors.primary,
      actions: [
        AppCta(
          label: widget.completion ? l.taskComplete : l.taskSave,
          color: AppColors.primary,
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, text.text.trim());
            }
          },
        ),
        AppCta(
          label: l.taskDismiss,
          color: AppColors.surfaceContainer,
          foreground: AppColors.primary,
          shadow: false,
          onPressed: () => Navigator.pop(context),
        ),
      ],
      child: Form(
        key: form,
        child: TextFormField(
          controller: text,
          maxLength: 4000,
          maxLines: 4,
          validator: (v) =>
              !widget.completion && (v == null || v.trim().isEmpty)
              ? l.taskCommentRequired
              : null,
        ),
      ),
    );
  }
}

class _TaskPhoto extends StatelessWidget {
  const _TaskPhoto({required this.attachment, required this.task});
  final TaskAttachment attachment;
  final HouseholdTask task;
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TasksViewModel>();
    final l = context.taskCopy;
    final url = vm.photoURL(attachment);
    final canShow = url != null && !vm.cached && !task.archived;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canShow)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    url,
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Text(l.taskPhotoError),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Material(
                    color: Colors.white.withAlpha(230),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: l.taskViewPhoto,
                      icon: const Icon(Icons.zoom_in, color: AppColors.text),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          insetPadding: const EdgeInsets.all(12),
                          child: InteractiveViewer(child: Image.network(url)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: vm.cached || task.archived
                    ? null
                    : () => vm.signPhoto(attachment),
                icon: const Icon(Icons.photo_outlined, size: 18),
                label: Text(url == null ? l.taskLoadPhoto : l.taskRefreshPhoto),
              ),
              if (!task.archived && vm.canRemovePhoto(attachment))
                TextButton(
                  onPressed: vm.busy || vm.cached
                      ? null
                      : () async {
                          if (await confirmTask(
                                context,
                                l.taskRemovePhotoQuestion,
                              ) &&
                              context.mounted &&
                              await vm.removePhoto(task, attachment) != null) {
                            await vm.open(task.id);
                          }
                        },
                  child: Text(l.taskRemovePhoto),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskActivityTile extends StatelessWidget {
  const _TaskActivityTile(this.event);
  final TaskActivity event;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    final label = switch (event.action) {
      'created' => l.taskActivityCreated,
      'updated' => l.taskActivityUpdated,
      'assigned' => l.taskActivityAssigned,
      'claimed' => l.taskActivityClaimed,
      'unassigned' => l.taskActivityUnassigned,
      'priority_changed' => l.taskActivityPriority,
      'status_changed' => l.taskActivityStatus,
      'completed' => l.taskActivityCompleted,
      'cancelled' => l.taskActivityCancelled,
      'reopened' => l.taskActivityReopened,
      'archived' => l.taskActivityArchived,
      'restored' => l.taskActivityRestored,
      'comment_added' => l.taskActivityCommentAdded,
      'comment_edited' => l.taskActivityCommentEdited,
      'comment_deleted' => l.taskActivityCommentDeleted,
      'attachment_added' => l.taskActivityPhotoAdded,
      'attachment_removed' => l.taskActivityPhotoRemoved,
      _ => l.taskActivity,
    };
    final actor = event.actorName?.isNotEmpty == true
        ? event.actorName
        : event.data['actor_user_id'] == null
        ? l.taskSystem
        : l.taskFormerMember;
    final extra = details(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconTile(
            icon: Icons.history,
            bg: AppColors.surfaceContainer,
            fg: AppColors.primary,
            size: 32,
            iconSize: 18,
            radius: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppText.labelLg.copyWith(color: AppColors.text),
                ),
                Text(
                  '$actor · ${taskTimestamp(context, event.data['created_at'])}',
                  style: AppText.bodySm.copyWith(color: AppColors.muted),
                ),
                if (extra.isNotEmpty)
                  Text(
                    extra,
                    style: AppText.bodySm.copyWith(color: AppColors.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String details(BuildContext context) {
    final l = context.taskCopy;
    final labels = {
      'priority': l.taskPriority,
      'status': l.taskStatus,
      'title': l.taskTitleField,
      'due_date': l.taskDueDate,
      'completion_note': l.taskCompletionNote,
    };
    return event.changes.entries
        .where((e) => labels.containsKey(e.key) && e.value is Map)
        .map((e) {
          final change = e.value as Map;
          return '${labels[e.key]}: ${change['before'] == null ? '—' : taskLabel(context, change['before'].toString())} → ${change['after'] == null ? '—' : taskLabel(context, change['after'].toString())}';
        })
        .join('\n');
  }
}
