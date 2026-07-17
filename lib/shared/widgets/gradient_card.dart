import 'package:flutter/material.dart';

import 'package:fast_flow/core/constants/app_spacing.dart';

/// A card with a gradient background, rounded corners, and optional tap handler.
class GradientCard extends StatelessWidget {
  final Gradient gradient;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final double? elevation;

  const GradientCard({
    required this.gradient,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius,
    this.elevation,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppSpacing.cardRadius;

    return Material(
      elevation: elevation ?? 0,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Padding(
            padding: padding ??
                const EdgeInsets.all(AppSpacing.xl),
            child: child,
          ),
        ),
      ),
    );
  }
}
