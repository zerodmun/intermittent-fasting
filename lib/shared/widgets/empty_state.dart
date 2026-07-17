import 'package:flutter/material.dart';
import '../../core/constants/app_spacing.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? illustrationPath;
  final Widget? action;

  const EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.illustrationPath,
    this.action,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (illustrationPath != null)
              Image.asset(
                illustrationPath!,
                height: 180,
                errorBuilder: (_, __, ___) => Icon(
                  icon,
                  size: AppSpacing.iconXxl * 2.5,
                  color: colorScheme.primary.withValues(alpha: 0.4),
                ),
              )
            else
              Icon(
                icon,
                size: AppSpacing.iconXxl * 2.5,
                color: colorScheme.primary.withValues(alpha: 0.4),
              ),
            const SizedBox(height: AppSpacing.xlg),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xlg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}