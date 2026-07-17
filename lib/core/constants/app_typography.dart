import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Typography system for FastFlow.
class AppTypography {
  AppTypography._();

  // ── Font Weights ──
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;

  // ── Line Heights ──
  static const double lineHeightTight = 1.1;
  static const double lineHeightNormal = 1.4;
  static const double lineHeightRelaxed = 1.6;

  // ── Text Styles (Google Fonts Inter base) ──
  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: 57,
        fontWeight: regular,
        height: lineHeightTight,
        letterSpacing: -0.25,
      );

  static TextStyle get displayMedium => GoogleFonts.inter(
        fontSize: 45,
        fontWeight: regular,
        height: lineHeightTight,
        letterSpacing: 0,
      );

  static TextStyle get displaySmall => GoogleFonts.inter(
        fontSize: 36,
        fontWeight: regular,
        height: lineHeightTight,
        letterSpacing: 0,
      );

  static TextStyle get headlineLarge => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: bold,
        height: lineHeightNormal,
        letterSpacing: 0,
      );

  static TextStyle get headlineMedium => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: semiBold,
        height: lineHeightNormal,
        letterSpacing: 0,
      );

  static TextStyle get headlineSmall => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: semiBold,
        height: lineHeightNormal,
        letterSpacing: 0,
      );

  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: semiBold,
        height: lineHeightNormal,
        letterSpacing: 0,
      );

  static TextStyle get titleMedium => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: medium,
        height: lineHeightNormal,
        letterSpacing: 0.15,
      );

  static TextStyle get titleSmall => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: medium,
        height: lineHeightNormal,
        letterSpacing: 0.1,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: regular,
        height: lineHeightRelaxed,
        letterSpacing: 0.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: regular,
        height: lineHeightRelaxed,
        letterSpacing: 0.25,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: regular,
        height: lineHeightRelaxed,
        letterSpacing: 0.4,
      );

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: medium,
        height: lineHeightNormal,
        letterSpacing: 0.1,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: medium,
        height: lineHeightNormal,
        letterSpacing: 0.5,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: medium,
        height: lineHeightNormal,
        letterSpacing: 0.5,
      );
}