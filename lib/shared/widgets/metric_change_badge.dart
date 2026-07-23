import 'package:flutter/material.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';

class MetricChangeBadge extends StatelessWidget {
  final double change;
  final String unit;
  final bool isDecreaseSuccess; // e.g. True for weight/fat loss, False for muscle/lean mass gain

  const MetricChangeBadge({
    required this.change,
    required this.unit,
    this.isDecreaseSuccess = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNegative = change < 0;
    final isZero = change == 0;

    if (isZero) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Text(
          'No change',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final isSuccess = (isNegative && isDecreaseSuccess) || (!isNegative && !isDecreaseSuccess);
    final badgeColor = isSuccess ? context.colors.successContainer : theme.colorScheme.errorContainer;
    final textColor = isSuccess ? context.colors.onSuccessContainer : theme.colorScheme.onErrorContainer;
    final icon = isNegative ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    final sign = isNegative ? '' : '+';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSpacing.iconSm - 4, color: textColor),
          const SizedBox(width: 4),
          Text(
            '$sign${change.toStringAsFixed(1)} $unit',
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
