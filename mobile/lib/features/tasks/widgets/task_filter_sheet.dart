import 'package:flutter/material.dart';

import '../models/household_task.dart';
import 'task_widgets.dart';

class TaskFilterSheet extends StatefulWidget {
  const TaskFilterSheet({
    required this.initial,
    required this.members,
    super.key,
  });
  final Map<String, String> initial;
  final List<Map<String, dynamic>> members;
  @override
  State<TaskFilterSheet> createState() => _TaskFilterSheetState();
}

class _TaskFilterSheetState extends State<TaskFilterSheet> {
  late Map<String, String> fields = {...widget.initial};
  void update(String key, String? value) => setState(() {
    if (value == null || value.isEmpty) {
      fields.remove(key);
    } else {
      fields[key] = value;
    }
  });
  Future<void> pick(String key) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: DateTime.tryParse(fields[key] ?? '') ?? DateTime.now(),
    );
    if (selected != null && mounted) {
      update(key, selected.toIso8601String().substring(0, 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    return SafeArea(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.taskFilters,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              taskDropdown(
                l.taskAssignedTo,
                fields['assignment'] ?? 'all',
                [
                  ('all', l.taskAllTasks),
                  ('me', l.taskAssignedToMe),
                  ('unassigned', l.taskUnassigned),
                ],
                (v) {
                  fields.remove('assigned_to');
                  update('assignment', v);
                },
              ),
              const SizedBox(height: 12),
              AssigneeSelector(
                members: widget.members,
                value: fields['assigned_to'],
                onChanged: (v) {
                  fields['assignment'] = 'all';
                  update('assigned_to', v);
                },
              ),
              const SizedBox(height: 12),
              taskDropdown(l.taskPriority, fields['priority'] ?? '', [
                ('', l.taskAny),
                ...TaskPriority.values.map(
                  (v) => (v.name, taskLabel(context, v.name)),
                ),
              ], (v) => update('priority', v)),
              const SizedBox(height: 12),
              taskDropdown(l.taskStatus, fields['status'] ?? '', [
                ('', l.taskAny),
                ...TaskStatus.values.map(
                  (v) => (statusWire(v), taskLabel(context, statusWire(v))),
                ),
              ], (v) => update('status', v)),
              const SizedBox(height: 12),
              taskDropdown(l.taskSort, fields['sort'] ?? 'priority', [
                ('priority', l.taskSortPriority),
                ('updated', l.taskSortUpdated),
                ('due_date', l.taskSortDue),
              ], (v) => update('sort', v)),
              for (final key in ['due_after', 'due_before'])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    key == 'due_after' ? l.taskDueAfter : l.taskDueBefore,
                  ),
                  subtitle: Text(fields[key] ?? l.taskAny),
                  onTap: () => pick(key),
                  trailing: IconButton(
                    tooltip: l.taskClearDate,
                    onPressed: () => update(key, null),
                    icon: const Icon(Icons.clear),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.taskOverdue),
                value: fields['overdue'] == 'true',
                onChanged: (v) => update('overdue', '$v'),
              ),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, <String, String>{}),
                    child: Text(l.taskClearFilters),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, fields),
                    child: Text(l.taskApplyFilters),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
