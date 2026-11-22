import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// "What would you like to do?" sheet (UI/global_quick_actions).
Future<void> showQuickActionsSheet(
  BuildContext context, {
  required String householdName,
}) {
  final router = GoRouter.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheet) {
      void go(void Function() action) {
        Navigator.of(sheet).pop();
        action();
      }

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC4C5D7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.home_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                householdName.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.labelSm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'What would you like to do?',
                          style: AppText.headlineMd.copyWith(
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Keep your home running smoothly.',
                          style: AppText.bodyMd.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.surfaceContainer,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(sheet).pop(),
                      icon: const Icon(Icons.close, color: AppColors.text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Row(
                icon: Icons.inventory_2_outlined,
                tile: AppColors.surfaceHigh,
                fg: AppColors.primary,
                title: 'Add Inventory',
                chip: 'Inventory Form',
                chipBg: AppColors.surfaceHigh,
                chipFg: AppColors.primary,
                subtitle: 'Track supplies, groceries, or appliances.',
                onTap: () => go(() => router.pushNamed('addInventory')),
              ),
              _Row(
                icon: Icons.add_shopping_cart,
                tile: const Color(0xFF82F9C1),
                fg: AppColors.secondary,
                title: 'Add Shopping',
                chip: 'Shopping List',
                chipBg: const Color(0xFF82F9C1),
                chipFg: AppColors.secondary,
                subtitle: 'Something your family needs from the store.',
                onTap: () => go(() => router.pushNamed('addShopping')),
              ),
              _Row(
                icon: Icons.build_outlined,
                tile: const Color(0xFFFFDAD6),
                fg: const Color(0xFFBA1A1A),
                title: 'Report a Problem',
                chip: 'Quick Repair',
                chipBg: const Color(0xFFFFDAD6),
                chipFg: const Color(0xFFBA1A1A),
                subtitle: 'Report something broken, leaking, or damaged.',
                onTap: () => go(
                  () => router.pushNamed(
                    'createTask',
                    queryParameters: {'type': 'repair'},
                  ),
                ),
              ),
              _Row(
                icon: Icons.checklist,
                tile: AppColors.surfaceHigh,
                fg: AppColors.primary,
                title: 'Create Task',
                chip: 'Tasks Overview',
                chipBg: AppColors.surfaceHigh,
                chipFg: AppColors.primary,
                subtitle: 'Assign or organize household chores.',
                onTap: () => go(() => router.pushNamed('createTask')),
              ),
              _Row(
                icon: Icons.forum_outlined,
                tile: const Color(0xFF82F9C1),
                fg: AppColors.text,
                title: 'Send Family Message',
                chip: 'Family Chat',
                chipBg: const Color(0xFF82F9C1),
                chipFg: AppColors.secondary,
                subtitle: 'Talk to everyone at home in group chat.',
                onTap: () => go(() => router.goNamed('chat')),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  onPressed: () => Navigator.of(sheet).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.surfaceHigh,
                    foregroundColor: AppColors.text,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text('Cancel', style: AppText.labelLg),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Syncing instantly with household members',
                    style: AppText.bodySm.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.tile,
    required this.fg,
    required this.title,
    required this.chip,
    required this.chipBg,
    required this.chipFg,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color tile;
  final Color fg;
  final String title;
  final String chip;
  final Color chipBg;
  final Color chipFg;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 10),
    child: Material(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tile,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: fg, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.labelLg.copyWith(
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            chip,
                            style: AppText.labelSm.copyWith(
                              color: chipFg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    ),
  );
}
