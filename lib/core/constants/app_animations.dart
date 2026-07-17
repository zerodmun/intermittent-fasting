import 'package:flutter/material.dart';

/// Centralized Animation system for FastFlow.
class AppAnimations {
  AppAnimations._();

  // ── Durations ──
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration extraSlow = Duration(milliseconds: 800);

  // ── Curves ──
  static const Curve emphasized = Curves.easeInOutCubic;
  static const Curve standard = Curves.fastOutSlowIn;
  static const Curve decelerate = Curves.easeOutCubic;
  static const Curve accelerate = Curves.easeInCubic;

  // ── Transition Helper Builders ──
  static Widget fadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: decelerate,
      ),
      child: child,
    );
  }

  static Widget scaleTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: animation,
        curve: decelerate,
      ),
      child: child,
    );
  }

  static Widget slideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child, {
    Offset begin = const Offset(0.0, 0.1),
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: begin,
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: decelerate,
        ),
      ),
      child: child,
    );
  }
}
