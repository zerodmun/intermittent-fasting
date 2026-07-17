import 'package:flutter/material.dart';

import 'package:fast_flow/core/constants/app_spacing.dart';

/// Compact tile showing an icon, label, and value — used in stat grids.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  final Color? iconBackgroundColor;

  const StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.iconBackgroundColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileColor = color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: (iconBackgroundColor ?? tileColor).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Icon(
              icon,
              size: AppSpacing.iconMd,
              color: tileColor,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: tileColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
