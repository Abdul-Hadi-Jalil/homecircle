import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../viewmodels/tasks_view_model.dart';
import 'task_widgets.dart';

class RelatedRepairs extends StatefulWidget {
  const RelatedRepairs({
    required this.itemId,
    required this.itemName,
    this.canCreate = true,
    super.key,
  });
  final String itemId, itemName;
  final bool canCreate;
  @override
  State<RelatedRepairs> createState() => _RelatedRepairsState();
}

class _RelatedRepairsState extends State<RelatedRepairs> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<TasksViewModel>().loadRelated(widget.itemId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy, vm = context.watch<TasksViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Text(
          l.taskRelatedRepairs,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (vm.relatedItemId == widget.itemId) ...[
          if (vm.relatedLoading) const LinearProgressIndicator(),
          if (vm.relatedError != null)
            TaskNotice(taskError(context, vm.relatedError)),
          if (!vm.relatedLoading &&
              vm.related.isEmpty &&
              vm.relatedError == null)
            Text(l.taskNoRelated),
          for (final task in vm.related)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(task.title),
              subtitle: Text(taskLabel(context, task.data['status'] as String)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await context.pushNamed(
                  'taskDetails',
                  pathParameters: {'id': task.id},
                );
                if (mounted) await vm.loadRelated(widget.itemId);
              },
            ),
        ],
        TextButton(
          onPressed: () async {
            await context.pushNamed(
              'tasks',
              queryParameters: {'item': widget.itemId},
            );
            if (mounted) await vm.loadRelated(widget.itemId);
          },
          child: Text(l.taskAllRelated),
        ),
        if (widget.canCreate)
          OutlinedButton.icon(
            onPressed: () async {
              await context.pushNamed(
                'createTask',
                queryParameters: {
                  'type': 'repair',
                  'item': widget.itemId,
                  'itemName': widget.itemName,
                },
              );
              if (mounted) await vm.loadRelated(widget.itemId);
            },
            icon: const Icon(Icons.build_outlined),
            label: Text(l.taskReportRepair),
          ),
      ],
    );
  }
}
