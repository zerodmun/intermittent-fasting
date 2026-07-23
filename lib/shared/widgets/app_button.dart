import 'package:flutter/material.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/constants/app_animations.dart';

enum AppButtonVariant { primary, secondary, outlined, text }

enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final AppButtonVariant variant;
  final AppButtonSize size;

  const AppButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    super.key,
  });

  const AppButton.primary({
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.size = AppButtonSize.md,
    super.key,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.size = AppButtonSize.md,
    super.key,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outlined({
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.size = AppButtonSize.md,
    super.key,
  }) : variant = AppButtonVariant.outlined;

  const AppButton.text({
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.size = AppButtonSize.md,
    super.key,
  }) : variant = AppButtonVariant.text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine padding based on size
    final EdgeInsets padding;
    final double fontSize;
    final double iconSize;
    final double radius;

    switch (size) {
      case AppButtonSize.sm:
        padding = const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        );
        fontSize = 13.0;
        iconSize = AppSpacing.iconSm;
        radius = AppSpacing.radiusSm;
        break;
      case AppButtonSize.md:
        padding = const EdgeInsets.symmetric(
          horizontal: AppSpacing.xlg,
          vertical: AppSpacing.md,
        );
        fontSize = 15.0;
        iconSize = AppSpacing.iconMd;
        radius = AppSpacing.radiusMd;
        break;
      case AppButtonSize.lg:
        padding = const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        );
        fontSize = 17.0;
        iconSize = AppSpacing.iconLg;
        radius = AppSpacing.radiusLg;
        break;
    }

    // Determine colors
    final Color bgColor;
    final Color fgColor;
    final BorderSide border;

    switch (variant) {
      case AppButtonVariant.primary:
        bgColor = onPressed == null ? colorScheme.onSurface.withValues(alpha: 0.12) : colorScheme.primary;
        fgColor = onPressed == null ? colorScheme.onSurface.withValues(alpha: 0.38) : colorScheme.onPrimary;
        border = BorderSide.none;
        break;
      case AppButtonVariant.secondary:
        bgColor = onPressed == null ? colorScheme.onSurface.withValues(alpha: 0.04) : colorScheme.surfaceContainerHighest;
        fgColor = onPressed == null ? colorScheme.onSurface.withValues(alpha: 0.38) : colorScheme.onSurfaceVariant;
        border = BorderSide.none;
        break;
      case AppButtonVariant.outlined:
        bgColor = Colors.transparent;
        fgColor = onPressed == null ? colorScheme.onSurface.withValues(alpha: 0.38) : colorScheme.primary;
        border = BorderSide(
          color: onPressed == null ? colorScheme.onSurface.withValues(alpha: 0.12) : colorScheme.outline,
          width: 1.5,
        );
        break;
      case AppButtonVariant.text:
        bgColor = Colors.transparent;
        fgColor = onPressed == null ? colorScheme.onSurface.withValues(alpha: 0.38) : colorScheme.primary;
        border = BorderSide.none;
        break;
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              color: fgColor,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: iconSize, color: fgColor),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontSize: fontSize,
            color: fgColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    if (isFullWidth) {
      content = Center(child: content);
    }

    final buttonStyle = TextButton.styleFrom(
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      padding: padding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: border,
      ),
      disabledBackgroundColor: variant == AppButtonVariant.primary
          ? colorScheme.onSurface.withValues(alpha: 0.12)
          : variant == AppButtonVariant.secondary
              ? colorScheme.onSurface.withValues(alpha: 0.04)
              : Colors.transparent,
      disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
      animationDuration: AppAnimations.fast,
    );

    return AnimatedSize(
      duration: AppAnimations.fast,
      child: isFullWidth
          ? SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: isLoading ? null : onPressed,
                style: buttonStyle,
                child: content,
              ),
            )
          : TextButton(
              onPressed: isLoading ? null : onPressed,
              style: buttonStyle,
              child: content,
            ),
    );
  }
}
