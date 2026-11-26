import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rounded placeholder block used by skeleton loading states.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.width,
    this.height = 12,
    this.radius = 8,
    this.strong = true,
    super.key,
  });
  final double? width;
  final double height;
  final double radius;
  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: strong ? const Color(0xFFDDE5FB) : const Color(0xFFEBF0FF),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Placeholder shaped like an inventory list card.
class InventoryCardSkeleton extends StatelessWidget {
  const InventoryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.sm,
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 52, height: 52, radius: 14),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 14),
                SizedBox(height: 8),
                SkeletonBox(width: 150, height: 10),
                SizedBox(height: 8),
                SkeletonBox(width: 80, height: 18, radius: 9, strong: false),
              ],
            ),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonBox(width: 50, height: 22, radius: 11),
              SizedBox(height: 10),
              SkeletonBox(width: 34, height: 10),
            ],
          ),
        ],
      ),
    ),
  );
}
