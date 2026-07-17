import 'package:flutter/material.dart';

/// Centralized color system for FastFlow.
///
/// Provides semantic color tokens for light and dark themes.
/// Use these instead of raw Material colors for consistency.
abstract final class AppColors {
  // ── Primary Teal Palette ──
  static const teal50 = Color(0xFFE0F2F1);
  static const teal100 = Color(0xFFB2DFDB);
  static const teal200 = Color(0xFF80CBC4);
  static const teal300 = Color(0xFF4DB6AC);
  static const teal400 = Color(0xFF26A69A);
  static const teal500 = Color(0xFF009688);
  static const teal600 = Color(0xFF00897B);
  static const teal700 = Color(0xFF00796B);

  // ── Accent Amber Palette ──
  static const amber50 = Color(0xFFFFF8E1);
  static const amber100 = Color(0xFFFFECB3);
  static const amber200 = Color(0xFFFFE082);
  static const amber300 = Color(0xFFFFD54F);
  static const amber400 = Color(0xFFFFCA28);

  // ── Semantic: Fasting / Eating ──
  static const fastingActive = Color(0xFF00BFA5);
  static const fastingActiveDark = Color(0xFF64FFDA);
  static const eatingActive = Color(0xFFFFB74D);
  static const eatingActiveDark = Color(0xFFFFE082);

  // ── Semantic: Status ──
  static const success = Color(0xFF66BB6A);
  static const successDark = Color(0xFF81C784);
  static const warning = Color(0xFFFFA726);
  static const warningDark = Color(0xFFFFCC80);
  static const error = Color(0xFFEF5350);
  static const errorDark = Color(0xFFEF9A9A);

  // ── Surfaces ──
  static const surfaceLight = Colors.white;
  static const surfaceDark = Color(0xFF1E1E2E);
  static const backgroundLight = Color(0xFFF5F7FA);
  static const backgroundDark = Color(0xFF121218);
  static const cardLight = Colors.white;
  static const cardDark = Color(0xFF252538);

  // ── Text ──
  static const textPrimaryLight = Color(0xFF1A1A2E);
  static const textPrimaryDark = Color(0xFFE8E8F0);
  static const textSecondaryLight = Color(0xFF6B7280);
  static const textSecondaryDark = Color(0xFF9CA3AF);

  // ── Gradient Presets ──
  static const fastingGradient = LinearGradient(
    colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const eatingGradient = LinearGradient(
    colors: [Color(0xFFFFB74D), Color(0xFFF57C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF26A69A), Color(0xFF00796B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
