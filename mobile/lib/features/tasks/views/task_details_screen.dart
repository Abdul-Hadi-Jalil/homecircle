import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_widgets.dart';
import '../models/household_task.dart';
import '../models/task_comment.dart';
import '../models/task_activity.dart';
import '../viewmodels/tasks_view_model.dart';
import '../widgets/task_widgets.dart';
import '../widgets/task_photo_picker.dart';

class TaskDetailsScreen extends StatefulWidget {
  const TaskDetailsScreen({required this.id, super.key});
  final String id;
  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final composer = TextEditingController();
  late String scope;
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
    final change = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.taskConditionQuestion),
        content: Text(l.taskConditionHelp),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.taskKeepCondition),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.taskMarkWorking),
          ),
        ],
      ),
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
    final result = await showDialog<(String?,)>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.taskCopy.taskReassign),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, (null,)),
            child: Text(context.taskCopy.taskUnassign),
          ),
          for (final member in vm.members)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, (member['user_id'] as String,)),
              child: Text(
                (member['display_name'] as String?)?.isNotEmpty == true
                    ? member['display_name'] as String
                    : context.taskCopy.taskFormerMember,
              ),
            ),
        ],
      ),
    );
    if (result != null &&
        mounted &&
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

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy,
        vm = context.watch<TasksViewModel>(),
        selected = vm.task;
    return AppScaffold(
      title: l.taskDetailsTitle,
      actions: [
        IconButton(
          tooltip: l.taskRefresh,
          onPressed: vm.detailLoading || vm.busy
              ? null
              : () => vm.open(widget.id),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (vm.errorCode != null)
            TaskNotice(taskError(context, vm.errorCode)),
          if (vm.cached) TaskNotice(l.taskCached),
          if (vm.detailLoading) const LinearProgressIndicator(),
          if (selected != null && selected.id == widget.id) ...[
            TaskSection(
              children: [
                Text(
                  selected.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(taskLabel(context, selected.kind.name))),
                    PriorityBadge(selected.priority),
                    StatusBadge(selected.status),
                    if (selected.archived) Chip(label: Text(l.taskArchived)),
                  ],
                ),
                if (selected.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(selected.description),
                  ),
              ],
            ),
            TaskSection(
              title: l.taskDetails,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final cell in [
                        (
                          l.taskCreatedBy,
                          selected.creatorName?.isNotEmpty == true
                              ? selected.creatorName!
                              : l.taskFormerMember,
                          Icons.person_outline,
                        ),
                        (
                          l.taskAssignedTo,
                          selected.assigneeName?.isNotEmpty == true
                              ? selected.assigneeName!
                              : selected.assignedTo == null
                              ? l.taskUnassigned
                              : l.taskFormerMember,
                          Icons.group_outlined,
                        ),
                        (
                          l.taskDueDate,
                          selected.dueDate ?? l.taskNoDueDate,
                          Icons.calendar_today_outlined,
                        ),
                        (
                          l.taskLocation,
                          selected.data['location'] as String? ?? l.taskAny,
                          Icons.location_on_outlined,
                        ),
                      ])
                        SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          child: TaskInfoCell(
                            label: cell.$1,
                            value: cell.$2,
                            icon: cell.$3,
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected.overdue()) TaskNotice(l.taskOverdue),
              ],
            ),
            if (selected.linkedItemId != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(l.taskLinkedItem),
                  subtitle: Text(selected.linkedItemName ?? l.taskLinkedItem),
                  onTap: () async {
                    await context.pushNamed(
                      'inventoryDetails',
                      pathParameters: {'id': selected.linkedItemId!},
                    );
                    if (mounted) await refresh(vm, force: true);
                  },
                ),
              ),
            if (selected.data['completion_note'] != null)
              TaskNotice(
                '${l.taskCompletionHistory}: ${selected.data['completion_note']}',
              ),
            if (vm.busy) ...[
              const LinearProgressIndicator(),
              Text(l.taskSaving),
            ],
            const SizedBox(height: 16),
            TaskSection(
              title: l.taskStatus,
              children: [
                if (!selected.archived && selected.kind != TaskKind.shopping)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: vm.busy || vm.cached
                            ? null
                            : () async {
                                await context.pushNamed(
                                  'editTask',
                                  pathParameters: {'id': selected.id},
                                );
                                if (mounted) await refresh(vm, force: true);
                              },
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l.taskEdit),
                      ),
                      OutlinedButton(
                        onPressed: vm.busy || vm.cached
                            ? null
                            : () => assign(vm, selected),
                        child: Text(l.taskReassign),
                      ),
                      if (selected.assignedTo == null && !selected.terminal)
                        OutlinedButton(
                          onPressed: vm.busy || vm.cached
                              ? null
                              : () async {
                                  if (await vm.assign(
                                        selected,
                                        'claim',
                                        null,
                                      ) !=
                                      null) {
                                    await refresh(vm);
                                  }
                                },
                          child: Text(l.taskTakeOwnership),
                        ),
                      PopupMenuButton<TaskPriority>(
                        enabled: !vm.busy && !vm.cached,
                        tooltip: l.taskChangePriority,
                        onSelected: (v) async {
                          if (await vm.setPriority(selected, v) != null) {
                            await refresh(vm);
                          }
                        },
                        itemBuilder: (_) => [
                          for (final p in TaskPriority.values)
                            if (p != selected.priority)
                              PopupMenuItem(
                                value: p,
                                child: Text(taskLabel(context, p.name)),
                              ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(l.taskChangePriority),
                        ),
                      ),
                      if (!selected.terminal) ...[
                        PopupMenuButton<TaskStatus>(
                          enabled: !vm.busy && !vm.cached,
                          tooltip: l.taskChangeStatus,
                          onSelected: (v) async {
                            if (await vm.setStatus(selected, v) != null) {
                              await refresh(vm);
                            }
                          },
                          itemBuilder: (_) => [
                            for (final status in [
                              TaskStatus.open,
                              TaskStatus.inProgress,
                              TaskStatus.blocked,
                            ])
                              if (status != selected.status)
                                PopupMenuItem(
                                  value: status,
                                  child: Text(
                                    taskLabel(context, statusWire(status)),
                                  ),
                                ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(l.taskChangeStatus),
                          ),
                        ),
                        FilledButton(
                          onPressed: vm.busy || vm.cached
                              ? null
                              : () => complete(vm, selected),
                          child: Text(l.taskComplete),
                        ),
                        TextButton(
                          onPressed: vm.busy || vm.cached
                              ? null
                              : () async {
                                  if (await confirmTask(
                                        context,
                                        l.taskCancel,
                                      ) &&
                                      mounted &&
                                      await vm.setStatus(
                                            selected,
                                            TaskStatus.cancelled,
                                          ) !=
                                          null) {
                                    await refresh(vm);
                                  }
                                },
                          child: Text(l.taskCancel),
                        ),
                      ] else
                        OutlinedButton(
                          onPressed: vm.busy || vm.cached
                              ? null
                              : () async {
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
                          child: Text(l.taskReopen),
                        ),
                    ],
                  ),
                TextButton.icon(
                  onPressed: vm.busy || vm.cached
                      ? null
                      : () async {
                          if (await confirmTask(
                                context,
                                selected.archived
                                    ? l.taskRestoreQuestion
                                    : l.taskArchiveQuestion,
                                message: selected.archived
                                    ? null
                                    : l.taskArchiveHelp,
                              ) &&
                              mounted &&
                              await vm.archive(selected) != null) {
                            await refresh(vm);
                          }
                        },
                  icon: Icon(
                    selected.archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  label: Text(
                    selected.archived ? l.taskRestore : l.taskArchive,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            TaskSection(
              children: [
                Text(
                  l.taskAttachments,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (vm.attachments.where((a) => a.commentId == null).isEmpty)
                  Text(l.taskNoAttachments),
                for (final attachment in vm.attachments.where(
                  (a) => a.commentId == null,
                ))
                  _TaskPhoto(attachment: attachment, task: selected),
                if (!selected.archived && selected.kind != TaskKind.shopping)
                  OutlinedButton.icon(
                    onPressed: vm.busy || vm.cached
                        ? null
                        : () => photo(vm, selected),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(l.taskAddPhoto),
                  ),
                if (vm.more('attachments'))
                  TextButton(
                    onPressed: vm.sectionBusy('attachments')
                        ? null
                        : () => vm.loadSection('attachments'),
                    child: Text(l.taskLoadMore),
                  ),
              ],
            ),
            const Divider(height: 32),
            TaskSection(
              children: [
                Text(
                  l.taskComments,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (vm.comments.isEmpty) Text(l.taskNoComments),
                for (final comment in vm.comments)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              child: Text(
                                (comment.authorName?.isNotEmpty == true
                                        ? comment.authorName!
                                        : '?')
                                    .substring(0, 1)
                                    .toUpperCase(),
                              ),
                            ),
                            title: Text(
                              comment.authorName?.isNotEmpty == true
                                  ? comment.authorName!
                                  : l.taskFormerMember,
                            ),
                            subtitle: Text(
                              taskTimestamp(
                                context,
                                comment.data['updated_at'],
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: .45),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(comment.body),
                          ),
                          for (final attachment in vm.attachments.where(
                            (a) => a.commentId == comment.id,
                          ))
                            _TaskPhoto(attachment: attachment, task: selected),
                          if (!selected.archived &&
                              vm.canChangeComment(comment))
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: vm.busy || vm.cached
                                      ? null
                                      : () async {
                                          final text = await showDialog<String>(
                                            context: context,
                                            builder: (_) => _TaskTextDialog(
                                              initial: comment.body,
                                            ),
                                          );
                                          if (text != null &&
                                              mounted &&
                                              await vm.editComment(
                                                    selected,
                                                    comment,
                                                    text,
                                                  ) !=
                                                  null) {
                                            await refresh(vm);
                                          }
                                        },
                                  child: Text(l.taskEditComment),
                                ),
                                TextButton(
                                  onPressed: vm.busy || vm.cached
                                      ? null
                                      : () async {
                                          if (await confirmTask(
                                                context,
                                                l.taskDeleteCommentQuestion,
                                              ) &&
                                              mounted &&
                                              await vm.deleteComment(
                                                    selected,
                                                    comment,
                                                  ) !=
                                                  null) {
                                            await refresh(vm);
                                          }
                                        },
                                  child: Text(l.taskDeleteComment),
                                ),
                                IconButton(
                                  tooltip: l.taskCommentPhoto,
                                  onPressed: vm.busy || vm.cached
                                      ? null
                                      : () => photo(
                                          vm,
                                          selected,
                                          commentId: comment.id,
                                        ),
                                  icon: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                if (vm.more('comments'))
                  TextButton(
                    onPressed: vm.sectionBusy('comments')
                        ? null
                        : () => vm.loadSection('comments'),
                    child: Text(l.taskLoadMore),
                  ),
                if (!selected.archived &&
                    selected.kind != TaskKind.shopping) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: composer,
                    maxLength: 4000,
                    maxLines: 3,
                    enabled: !vm.busy,
                    decoration: InputDecoration(labelText: l.taskAddComment),
                    onChanged: (v) => vm.saveDraft('comment.${widget.id}', {
                      'body': v,
                    }, scope),
                  ),
                  FilledButton(
                    onPressed: vm.busy || vm.cached
                        ? null
                        : () async {
                            if (composer.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l.taskCommentRequired)),
                              );
                              return;
                            }
                            final posted = await vm.addComment(
                              selected,
                              composer.text.trim(),
                            );
                            if (posted == null || !mounted) return;
                            composer.clear();
                            await vm.clearDraft('comment.${widget.id}', scope);
                            await refresh(vm);
                          },
                    child: Text(l.taskSendComment),
                  ),
                ],
              ],
            ),
            const Divider(height: 32),
            Card(
              child: ExpansionTile(
                title: Text(l.taskActivity),
                leading: const Icon(Icons.history),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  if (vm.activity.isEmpty) Text(l.taskNoActivity),
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
          ],
        ],
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
    return AlertDialog(
      title: Text(widget.completion ? l.taskCompletionNote : l.taskEditComment),
      content: Form(
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.taskDismiss),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, text.text.trim());
            }
          },
          child: Text(widget.completion ? l.taskComplete : l.taskSave),
        ),
      ],
    );
  }
}

class _TaskPhoto extends StatelessWidget {
  const _TaskPhoto({required this.attachment, required this.task});
  final TaskAttachment attachment;
  final HouseholdTask task;
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TasksViewModel>(),
        l = context.taskCopy,
        url = context.watch<TasksViewModel>().photoURL(attachment);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (url != null && !vm.cached && !task.archived)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                url,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Text(l.taskPhotoError),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: vm.cached || task.archived
                    ? null
                    : () => vm.signPhoto(attachment),
                icon: const Icon(Icons.photo_outlined),
                label: Text(url == null ? l.taskViewPhoto : l.taskRefreshPhoto),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.history),
      title: Text(label),
      subtitle: Text(
        '${event.actorName?.isNotEmpty == true
            ? event.actorName
            : event.data['actor_user_id'] == null
            ? l.taskSystem
            : l.taskFormerMember} · ${taskTimestamp(context, event.data['created_at'])}\n${details(context)}',
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
