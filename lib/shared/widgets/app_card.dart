import 'package:flutter/material.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';

enum AppCardVariant { standard, elevated, outlined, gradient }

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final AppCardVariant variant;
  final LinearGradient? gradient;
  final double? width;
  final double? height;

  const AppCard({
    required this.child,
    this.onTap,
    this.padding,
    this.width,
    this.height,
    super.key,
  })  : variant = AppCardVariant.standard,
        gradient = null;

  const AppCard.elevated({
    required this.child,
    this.onTap,
    this.padding,
    this.width,
    this.height,
    super.key,
  })  : variant = AppCardVariant.elevated,
        gradient = null;

  const AppCard.outlined({
    required this.child,
    this.onTap,
    this.padding,
    this.width,
    this.height,
    super.key,
  })  : variant = AppCardVariant.outlined,
        gradient = null;

  const AppCard.gradient({
    required this.child,
    required this.gradient,
    this.onTap,
    this.padding,
    this.width,
    this.height,
    super.key,
  }) : variant = AppCardVariant.gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    BoxDecoration decoration;
    double elevation = 0.0;

    switch (variant) {
      case AppCardVariant.standard:
        decoration = BoxDecoration(
          color: colorScheme.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        );
        break;
      case AppCardVariant.elevated:
        decoration = BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: AppSpacing.shadowSm(theme.brightness == Brightness.dark ? Colors.black : colorScheme.outline),
        );
        elevation = 2.0;
        break;
      case AppCardVariant.outlined:
        decoration = BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: colorScheme.outline),
        );
        break;
      case AppCardVariant.gradient:
        decoration = BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: gradient != null
              ? [
                  BoxShadow(
                    color: gradient!.colors.first.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        );
        break;
    }

    Widget content = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: content,
        ),
      );
    }

    return content;
  }
}
