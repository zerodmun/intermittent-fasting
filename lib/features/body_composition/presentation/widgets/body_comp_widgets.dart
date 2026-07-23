import 'package:flutter/material.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/features/body_composition/domain/entities/body_fat_category.dart';

class BodyFatCategoryBadge extends StatelessWidget {
  final BodyFatCategory category;

  const BodyFatCategoryBadge({required this.category, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final baseColor = category.color;
    final badgeColor = baseColor.withValues(alpha: isDark ? 0.25 : 0.12);
    final textColor = isDark ? baseColor.withValues(alpha: 0.95) : baseColor;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: baseColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        category.label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class BodyFatGauge extends StatelessWidget {
  final double bodyFatPercent;
  final BodyFatCategory category;

  const BodyFatGauge({
    required this.bodyFatPercent,
    required this.category,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final gaugeColor = category.color;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = (constraints.maxHeight < constraints.maxWidth
                      ? constraints.maxHeight
                      : constraints.maxWidth) * 0.85;
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: size,
                    height: size,
                    child: CircularProgressIndicator(
                      value: bodyFatPercent / 100,
                      strokeWidth: size * 0.08,
                      color: gaugeColor,
                      backgroundColor: colorScheme.outlineVariant,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${bodyFatPercent.toStringAsFixed(1)}%',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          fontSize: size * 0.20,
                        ),
                      ),
                      Text(
                        'Body Fat',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: size * 0.09,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        BodyFatCategoryBadge(category: category),
      ],
    );
  }
}
