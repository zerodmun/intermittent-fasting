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
    final isDark = theme.brightness == Brightness.dark;

    final BoxDecoration decoration;
    final shadow = AppCardStyle.getShadows(isDark);

    switch (variant) {
      case AppCardVariant.standard:
      case AppCardVariant.elevated:
      case AppCardVariant.outlined:
        decoration = BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24.0),
          boxShadow: shadow,
        );
        break;
      case AppCardVariant.gradient:
        decoration = BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24.0),
          boxShadow: shadow,
        );
        break;
    }

    final Widget content = Container(
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
          borderRadius: BorderRadius.circular(24.0),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// Helper class that defines the premium adaptive shadow/elevation system.
class AppCardStyle {
  AppCardStyle._();

  /// Returns the soft premium shadow hierarchy for cards, adapted to Light/Dark themes.
  static List<BoxShadow> getShadows(bool isDark) {
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.04),
          blurRadius: 2,
          spreadRadius: -1,
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
      ];
    }
  }
}

