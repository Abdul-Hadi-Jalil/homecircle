import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mock_widgets.dart';
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

/// Progress summary card (UI/shared_shopping_list).
class ShoppingProgressCard extends StatelessWidget {
  const ShoppingProgressCard(this.summary, {super.key});
  final ShoppingSummary summary;
  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy;
    return AppCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconTile(
                icon: Icons.shopping_cart_outlined,
                bg: AppColors.secondaryContainer,
                fg: AppColors.secondary,
                size: 40,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.shoppingProgress(summary.purchased, summary.total),
                  style: AppText.titleMd.copyWith(color: AppColors.text),
                ),
              ),
              Text(
                '${(summary.progress * 100).round()}%',
                style: AppText.headlineMd.copyWith(color: AppColors.secondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: summary.progress,
              minHeight: 8,
              color: AppColors.secondary,
              backgroundColor: AppColors.surfaceContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.shoppingOutstanding(
              summary.active,
              summary.highPriority,
              summary.assignedToMe,
            ),
            style: AppText.labelMd.copyWith(
              color: AppColors.muted,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// A list row: unchecked card or checked/struck-through purchased card.
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
    final disabled =
        busy || item.archived || item.status == TaskStatus.cancelled;
    final who =
        '${item.data[item.purchased ? 'purchaser_name' : 'creator_name'] ?? l.taskFormerMember}';
    final line =
        '${item.amount}${item.amount.isEmpty ? '' : ' • '}${item.purchased ? l.shoppingPurchasedBy : l.shoppingRequestedBy} $who';
    final bg = item.purchased
        ? AppColors.surfaceLow.withAlpha(200)
        : Colors.white;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsetsDirectional.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: item.purchased ? null : AppShadows.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: item.purchased
                    ? l.shoppingUndo
                    : l.shoppingMarkPurchased,
                child: InkWell(
                  key: const ValueKey('shopping-check'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: disabled ? null : onCheck,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: item.purchased
                          ? AppColors.secondary
                          : AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: item.purchased
                        ? const Icon(Icons.check, color: Colors.white, size: 24)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppText.headlineSm.copyWith(
                              color: item.purchased
                                  ? AppColors.muted
                                  : AppColors.text,
                              decoration: item.purchased
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (!item.purchased) ...[
                          const SizedBox(width: 6),
                          PriorityBadge(item.priority),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line,
                      style: AppText.bodyMd.copyWith(
                        color: item.purchased
                            ? AppColors.secondary
                            : AppColors.muted,
                      ),
                    ),
                    if (item.assignedTo != null && !item.purchased)
                      Text(
                        '${l.taskAssignedTo}: ${item.assigneeName ?? l.taskFormerMember}',
                        style: AppText.bodySm.copyWith(color: AppColors.muted),
                      ),
                    if (item.purchased)
                      Text(
                        taskTimestamp(context, item.data['purchased_at']),
                        style: AppText.bodySm.copyWith(color: AppColors.muted),
                      ),
                    if (item.linkedItemId != null && !item.purchased)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 8),
                        child: AppPill(
                          l.shoppingLinkedTo(
                            item.linkedItemName ?? l.taskLinkedItem,
                          ),
                          icon: Icons.inventory_2_outlined,
                          bg: AppColors.surfaceContainer,
                          fg: AppColors.muted,
                          radius: 8,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (item.purchased) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: disabled ? null : onCheck,
                  icon: const Icon(Icons.undo, size: 18),
                  label: Text(
                    l.shoppingUndoShort,
                    style: AppText.labelLg.copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
