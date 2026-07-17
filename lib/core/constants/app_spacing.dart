import 'package:flutter/material.dart';

/// Centralized Spacing, Border Radius, and Shadow systems.
class AppSpacing {
  AppSpacing._();

  // ── Spacing (Base unit: 4dp) ──
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double smd = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xlg = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double xxxxl = 48.0;

  // Screen padding & standard gaps
  static const double screenPadding = 16.0;
  static const double sectionSpacing = 24.0;
  static const double itemSpacing = 12.0;

  // ── Border Radius ──
  static const double radiusNone = 0.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 24.0;
  static const double radiusFull = 999.0;

  static BorderRadius get borderSm => BorderRadius.circular(radiusSm);
  static BorderRadius get borderMd => BorderRadius.circular(radiusMd);
  static BorderRadius get borderLg => BorderRadius.circular(radiusLg);
  static BorderRadius get borderXl => BorderRadius.circular(radiusXl);
  static BorderRadius get borderXxl => BorderRadius.circular(radiusXxl);
  static BorderRadius get borderFull => BorderRadius.circular(radiusFull);

  // ── Icon Sizes ──
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 28.0;
  static const double iconXxl = 32.0;

  // ── Elevations ──
  static const double elevationNone = 0.0;
  static const double elevationSm = 2.0;
  static const double elevationMd = 4.0;
  static const double elevationLg = 8.0;

  // ── Shadows (Using adaptive shadows based on theme color) ──
  static List<BoxShadow> shadowSm(Color shadowColor) => [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> shadowMd(Color shadowColor) => [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> shadowLg(Color shadowColor) => [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];
}