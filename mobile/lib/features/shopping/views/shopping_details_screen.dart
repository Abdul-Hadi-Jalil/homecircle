import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../tasks/widgets/task_widgets.dart';
import '../viewmodels/shopping_list_viewmodel.dart';
import '../widgets/shopping_widgets.dart';
import '../widgets/shopping_purchase_sheet.dart';

class ShoppingDetailsScreen extends StatefulWidget {
  const ShoppingDetailsScreen(this.id, {super.key});
  final String id;
  @override
  State<ShoppingDetailsScreen> createState() => _ShoppingDetailsScreenState();
}

class _ShoppingDetailsScreenState extends State<ShoppingDetailsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        final vm = context.read<ShoppingListViewModel>();
        vm.open(widget.id);
        vm.tasks.loadMembers();
      }
    });
  }

  Future<void> refresh() async {
    if (mounted) await context.read<ShoppingListViewModel>().open(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy,
        vm = context.watch<ShoppingListViewModel>(),
        item = vm.selected;
    return AppScaffold(
      title: l.shopping,
      actions: [
        IconButton(
          tooltip: l.taskRefresh,
          onPressed: vm.busy ? null : refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (vm.error != null) TaskNotice(shoppingError(context, vm.error)),
          if (vm.detailCached) TaskNotice(l.taskCached),
          if (vm.busy) const LinearProgressIndicator(),
          if (item == null && vm.error == null) const LinearProgressIndicator(),
          if (item != null && item.id == widget.id) ...[
            TaskSection(
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    PriorityBadge(item.priority),
                    Chip(label: Text(shoppingStatus(context, item.status))),
                  ],
                ),
                const SizedBox(height: 16),
                Text(item.amount),
                if (item.description.isNotEmpty) Text(item.description),
                Text(
                  '${l.shoppingRequestedBy}: ${item.creatorName ?? l.taskFormerMember}',
                ),
                Text(
                  '${l.taskAssignedTo}: ${item.assigneeName ?? l.taskUnassigned}',
                ),
                if (item.purchased) ...[
                  Text(
                    '${l.shoppingPurchasedBy}: ${item.data['purchaser_name'] ?? l.taskFormerMember}',
                  ),
                  Text(taskTimestamp(context, item.data['purchased_at'])),
                  if (item.data['purchase_price'] != null)
                    Text(
                      '${item.data['purchase_price']} ${item.data['currency_code']}',
                    ),
                ],
                if (item.linkedItemId != null)
                  TextButton.icon(
                    onPressed: () => context.pushNamed(
                      'inventoryDetails',
                      pathParameters: {'id': item.linkedItemId!},
                    ),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text(item.linkedItemName ?? l.taskLinkedItem),
                  ),
              ],
            ),
            if (!item.archived)
              TaskSection(
                children: [
                  if (!item.terminal) ...[
                    FilledButton.icon(
                      onPressed: vm.busy || vm.detailCached
                          ? null
                          : () async {
                              await purchaseShopping(context, item);
                              await refresh();
                            },
                      icon: const Icon(Icons.check),
                      label: Text(l.shoppingMarkPurchased),
                    ),
                    if (item.assignedTo == null)
                      OutlinedButton(
                        onPressed: vm.busy || vm.detailCached
                            ? null
                            : () async {
                                await vm.action(item, 'claim');
                                await refresh();
                              },
                        child: Text(l.shoppingClaim),
                      ),
                    OutlinedButton(
                      onPressed: vm.busy || vm.detailCached
                          ? null
                          : () async {
                              await context.pushNamed(
                                'editShopping',
                                pathParameters: {'id': item.id},
                              );
                              await refresh();
                            },
                      child: Text(l.taskEdit),
                    ),
                    OutlinedButton(
                      onPressed: vm.busy || vm.detailCached
                          ? null
                          : () async {
                              final result = await showDialog<(String?,)>(
                                context: context,
                                builder: (context) => SimpleDialog(
                                  title: Text(l.taskReassign),
                                  children: [
                                    SimpleDialogOption(
                                      onPressed: () =>
                                          Navigator.pop(context, (null,)),
                                      child: Text(l.taskUnassign),
                                    ),
                                    for (final member in vm.tasks.members)
                                      SimpleDialogOption(
                                        onPressed: () => Navigator.pop(
                                          context,
                                          (member['user_id'] as String,),
                                        ),
                                        child: Text(
                                          member['display_name'] as String? ??
                                              l.taskFormerMember,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                              if (result != null && context.mounted) {
                                await vm.action(
                                  item,
                                  'assignment',
                                  fields: {
                                    'operation': result.$1 == null
                                        ? 'unassign'
                                        : 'assign',
                                    'assigned_to': result.$1,
                                  },
                                );
                                await refresh();
                              }
                            },
                      child: Text(l.taskReassign),
                    ),
                    TextButton(
                      onPressed: vm.busy || vm.detailCached
                          ? null
                          : () async {
                              if (await confirmTask(context, l.taskCancel) &&
                                  context.mounted) {
                                await vm.action(item, 'cancel');
                                await refresh();
                              }
                            },
                      child: Text(l.taskCancel),
                    ),
                  ] else ...[
                    if (item.purchased && item.canApply)
                      OutlinedButton(
                        onPressed:
                            vm.busy || vm.detailCached || item.inventoryApplied
                            ? null
                            : () async {
                                await promptShoppingInventory(context, item);
                                await refresh();
                              },
                        child: Text(l.shoppingUpdateInventory),
                      ),
                    if (item.inventoryApplied)
                      TaskNotice(l.shoppingInventoryApplied),
                    OutlinedButton(
                      onPressed: vm.busy || vm.detailCached
                          ? null
                          : () async {
                              await undoShopping(context, item);
                              await refresh();
                            },
                      child: Text(
                        item.purchased ? l.shoppingUndo : l.taskReopen,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class ShoppingHistoryScreen extends StatefulWidget {
  const ShoppingHistoryScreen({super.key});
  @override
  State<ShoppingHistoryScreen> createState() => _ShoppingHistoryScreenState();
}

class _ShoppingHistoryScreenState extends State<ShoppingHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<ShoppingListViewModel>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy, vm = context.watch<ShoppingListViewModel>();
    return AppScaffold(
      title: l.shoppingHistory,
      actions: [
        IconButton(
          tooltip: l.taskRefresh,
          onPressed: vm.historyLoading ? null : () => vm.loadHistory(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (vm.historyCached) TaskNotice(l.taskCached),
          if (vm.error != null) TaskNotice(shoppingError(context, vm.error)),
          if (vm.historyLoading) const LinearProgressIndicator(),
          if (vm.history.isEmpty && !vm.historyLoading)
            Text(l.shoppingNoHistory),
          for (final row in vm.history)
            Card(
              child: ListTile(
                title: Text(
                  (row['purchase'] as Map?)?['title'] as String? ??
                      row['title'] as String,
                ),
                subtitle: Text(
                  '${(row['purchase'] as Map?)?['quantity'] ?? ''} ${(row['purchase'] as Map?)?['unit'] ?? ''} · ${row['actor_name'] ?? l.taskFormerMember}\n${taskTimestamp(context, row['created_at'])}\n${(row['purchase'] as Map?)?['purchase_price'] ?? ''} ${(row['purchase'] as Map?)?['currency_code'] ?? ''}',
                ),
                onTap: () => context.pushNamed(
                  'shoppingDetails',
                  pathParameters: {'id': row['task_id'] as String},
                ),
              ),
            ),
          if (vm.moreHistory)
            TextButton(
              onPressed: vm.historyLoading
                  ? null
                  : () => vm.loadHistory(nextPage: true),
              child: Text(l.taskLoadMore),
            ),
        ],
      ),
    );
  }
}
