import 'package:flutter/material.dart';
import 'package:fast_flow/core/constants/app_animations.dart';

class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    super.key,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.extraSlow,
    )..repeat();

    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [
                colorScheme.surfaceContainerHighest,
                colorScheme.outlineVariant.withValues(alpha: 0.5),
                colorScheme.surfaceContainerHighest,
              ],
              stops: const [0.3, 0.5, 0.7],
              begin: Alignment(_animation.value - 1.0, -0.3),
              end: Alignment(_animation.value + 1.0, 0.3),
            ),
          ),
        );
      },
    );
  }
}
