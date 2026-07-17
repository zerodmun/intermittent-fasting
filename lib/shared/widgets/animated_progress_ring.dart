import 'package:flutter/material.dart';
import '../../core/constants/app_animations.dart';

class AnimatedProgressRing extends StatefulWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color? backgroundColor;
  final Widget? child;
  final Duration duration;
  final Curve curve;
  final bool useGradient;
  final List<Color>? gradientColors;

  const AnimatedProgressRing({
    required this.progress,
    required this.size,
    this.strokeWidth = 8,
    required this.color,
    this.backgroundColor,
    this.child,
    this.duration = AppAnimations.extraSlow,
    this.curve = AppAnimations.decelerate,
    this.useGradient = false,
    this.gradientColors,
    super.key,
  });

  @override
  State<AnimatedProgressRing> createState() => _AnimatedProgressRingState();
}

class _AnimatedProgressRingState extends State<AnimatedProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.progress.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.progress.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _ProgressPainter(
              progress: _animation.value,
              strokeWidth: widget.strokeWidth,
              color: widget.color,
              backgroundColor: widget.backgroundColor ?? Theme.of(context).colorScheme.outlineVariant,
              useGradient: widget.useGradient,
              gradientColors: widget.gradientColors,
            ),
            child: Center(child: widget.child),
          );
        },
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;
  final Color backgroundColor;
  final bool useGradient;
  final List<Color>? gradientColors;

  _ProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.backgroundColor,
    required this.useGradient,
    this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0) return;

    // Progress arc
    final progressPaint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = -1.57079632679; // -90 degrees
    final sweepAngle = 2 * 3.14159265359 * progress;

    if (useGradient && gradientColors != null && gradientColors!.length >= 2) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      progressPaint.shader = SweepGradient(
        colors: gradientColors!,
        startAngle: 0.0,
        endAngle: 2 * 3.14159265359,
        transform: const GradientRotation(startAngle),
      ).createShader(rect);
    } else {
      progressPaint.color = color;
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _ProgressPainter &&
        (oldDelegate.progress != progress ||
            oldDelegate.color != color ||
            oldDelegate.backgroundColor != backgroundColor);
  }
}