import 'package:flutter/material.dart';
import 'app_theme_extensions.dart';

/// Semantic light color scheme for FastFlow.
const lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF0D9488), // Teal 600
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFCCFBF1),
  onPrimaryContainer: Color(0xFF115E59),
  secondary: Color(0xFFD97706), // Amber 600
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFFEF3C7),
  onSecondaryContainer: Color(0xFF92400E),
  tertiary: Color(0xFF4F46E5), // Indigo 600
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFE0E7FF),
  onTertiaryContainer: Color(0xFF3730A3),
  error: Color(0xFFDC2626), // Red 600
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFEE2E2),
  onErrorContainer: Color(0xFF991B1B),
  background: Color(0xFFF8FAFC), // Slate 50
  onBackground: Color(0xFF0F172A), // Slate 900
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF0F172A),
  surfaceVariant: Color(0xFFF1F5F9), // Slate 100
  onSurfaceVariant: Color(0xFF475569), // Slate 600
  outline: Color(0xFFCBD5E1), // Slate 300
  outlineVariant: Color(0xFFE2E8F0), // Slate 200
);

/// Semantic dark color scheme for FastFlow.
const darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF2DD4BF), // Teal 400
  onPrimary: Color(0xFF0F172A),
  primaryContainer: Color(0xFF115E59),
  onPrimaryContainer: Color(0xFFCCFBF1),
  secondary: Color(0xFFFBBF24), // Amber 400
  onSecondary: Color(0xFF0F172A),
  secondaryContainer: Color(0xFF92400E),
  onSecondaryContainer: Color(0xFFFEF3C7),
  tertiary: Color(0xFF818CF8), // Indigo 400
  onTertiary: Color(0xFF0F172A),
  tertiaryContainer: Color(0xFF3730A3),
  onTertiaryContainer: Color(0xFFE0E7FF),
  error: Color(0xFFF87171), // Red 400
  onError: Color(0xFF0F172A),
  errorContainer: Color(0xFF991B1B),
  onErrorContainer: Color(0xFFFEE2E2),
  background: Color(0xFF0B0F19), // Dark Rich Blue-Grey
  onBackground: Color(0xFFF8FAFC),
  surface: Color(0xFF111827), // Slate 900
  onSurface: Color(0xFFF8FAFC),
  surfaceVariant: Color(0xFF1F2937), // Slate 800
  onSurfaceVariant: Color(0xFF94A3B8), // Slate 400
  outline: Color(0xFF475569), // Slate 600
  outlineVariant: Color(0xFF334155), // Slate 700
);

/// Semantic color extensions for light theme.
const lightColorsExtension = AppColorsExtension(
  success: Color(0xFF16A34A), // Green 600
  onSuccess: Color(0xFFFFFFFF),
  successContainer: Color(0xFFDCFCE7),
  onSuccessContainer: Color(0xFF166534),
  warning: Color(0xFFEA580C), // Orange 600
  onWarning: Color(0xFFFFFFFF),
  warningContainer: Color(0xFFFFEDD5),
  onWarningContainer: Color(0xFF9A3412),
  info: Color(0xFF2563EB), // Blue 600
  onInfo: Color(0xFFFFFFFF),
  infoContainer: Color(0xFFDBEAFE),
  onInfoContainer: Color(0xFF1E40AF),
  fastingActive: Color(0xFF0D9488), // Teal 600
  eatingActive: Color(0xFFD97706), // Amber 600
  preparingActive: Color(0xFF4F46E5), // Indigo 600
  completedActive: Color(0xFF16A34A), // Green 600
  fastingGradient: LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  eatingGradient: LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  preparingGradient: LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  completedGradient: LinearGradient(
    colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
);

/// Semantic color extensions for dark theme.
const darkColorsExtension = AppColorsExtension(
  success: Color(0xFF4ADE80), // Green 400
  onSuccess: Color(0xFF0F172A),
  successContainer: Color(0xFF166534),
  onSuccessContainer: Color(0xFFDCFCE7),
  warning: Color(0xFFFB923C), // Orange 400
  onWarning: Color(0xFF0F172A),
  warningContainer: Color(0xFF9A3412),
  onWarningContainer: Color(0xFFFFEDD5),
  info: Color(0xFF60A5FA), // Blue 400
  onInfo: Color(0xFF0F172A),
  infoContainer: Color(0xFF1E40AF),
  onInfoContainer: Color(0xFFDBEAFE),
  fastingActive: Color(0xFF2DD4BF), // Teal 400
  eatingActive: Color(0xFFFBBF24), // Amber 400
  preparingActive: Color(0xFF818CF8), // Indigo 400
  completedActive: Color(0xFF4ADE80), // Green 400
  fastingGradient: LinearGradient(
    colors: [Color(0xFF115E59), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  eatingGradient: LinearGradient(
    colors: [Color(0xFF92400E), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  preparingGradient: LinearGradient(
    colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  completedGradient: LinearGradient(
    colors: [Color(0xFF166534), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
);