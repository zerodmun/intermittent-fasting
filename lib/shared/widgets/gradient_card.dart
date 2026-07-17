import 'package:flutter/material.dart';
import 'app_card.dart';

class GradientCard extends StatelessWidget {
  final LinearGradient gradient;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const GradientCard({
    required this.gradient,
    required this.child,
    this.onTap,
    this.padding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard.gradient(
      gradient: gradient,
      onTap: onTap,
      padding: padding,
      child: child,
    );
  }
}