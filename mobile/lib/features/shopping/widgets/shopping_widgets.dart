import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../tasks/models/household_task.dart';
import '../../tasks/widgets/task_widgets.dart';
import '../models/shopping_item.dart';
import '../models/shopping_summary.dart';

String shoppingError(BuildContext context, String? code) {
  final l = context.taskCopy;
  return switch (code) {
    'inventory_not_ready' || 'incompatible_unit' => l.shoppingUnitError,
    'reopen_required' ||
    'already_purchased' ||
    'purchase_changed' ||
    'explicit_reopen_required' => l.shoppingChanged,
    _ => taskError(context, code),
  };
}

String shoppingStatus(BuildContext context, TaskStatus status) =>
    switch (status) {
      TaskStatus.open => context.taskCopy.shoppingToBuy,
      TaskStatus.inProgress => context.taskCopy.shoppingBeingHandled,
      TaskStatus.completed => context.taskCopy.shoppingPurchased,
      TaskStatus.cancelled => context.taskCopy.shoppingCancelled,
      TaskStatus.blocked => context.taskCopy.taskBlocked,
    };

class ShoppingProgressCard extends StatelessWidget {
  const ShoppingProgressCard(this.summary, {super.key});
  final ShoppingSummary summary;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    return TaskSection(
      children: [
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFD6F8E9),
              foregroundColor: AppColors.success,
              child: Icon(Icons.shopping_cart_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.shoppingProgress(summary.purchased, summary.total),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${(summary.progress * 100).round()}%',
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: summary.progress,
          minHeight: 10,
          borderRadius: BorderRadius.circular(12),
          color: AppColors.success,
          backgroundColor: AppColors.lightBlue,
        ),
        const SizedBox(height: 12),
        Text(
          l.shoppingOutstanding(
            summary.active,
            summary.highPriority,
            summary.assignedToMe,
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class ShoppingItemTile extends StatelessWidget {
  const ShoppingItemTile({
    required this.item,
    required this.onTap,
    required this.onCheck,
    this.busy = false,
    super.key,
  });
  final ShoppingItem item;
  final VoidCallback onTap, onCheck;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    return Card(
      color: item.purchased
          ? AppColors.lightBlue.withValues(alpha: .65)
          : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: item.purchased,
                onChanged:
                    busy || item.archived || item.status == TaskStatus.cancelled
                    ? null
                    : (_) => onCheck(),
                semanticLabel: item.purchased
                    ? l.shoppingUndo
                    : l.shoppingMarkPurchased,
                activeColor: AppColors.success,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  decoration: item.purchased
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        PriorityBadge(item.priority),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.amount}${item.amount.isEmpty ? '' : ' · '}${item.purchased ? l.shoppingPurchasedBy : l.shoppingRequestedBy} ${item.data[item.purchased ? 'purchaser_name' : 'creator_name'] ?? l.taskFormerMember}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (item.assignedTo != null && !item.purchased)
                      Text(
                        '${l.taskAssignedTo}: ${item.assigneeName ?? l.taskFormerMember}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (item.purchased)
                      Text(
                        taskTimestamp(context, item.data['purchased_at']),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (item.linkedItemId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '↗ ${item.linkedItemName ?? l.taskLinkedItem}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
