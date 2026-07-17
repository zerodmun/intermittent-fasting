import 'package:flutter/material.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';
import 'color_schemes.dart';

/// Centralized Application theme builder for FastFlow.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return _buildTheme(
      colorScheme: lightColorScheme,
      extension: lightColorsExtension,
    );
  }

  static ThemeData get dark {
    return _buildTheme(
      colorScheme: darkColorScheme,
      extension: darkColorsExtension,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required ThemeExtension extension,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      extensions: [extension],

      // ── Typography & Text Theme ──
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(color: colorScheme.onBackground),
        displayMedium: AppTypography.displayMedium.copyWith(color: colorScheme.onBackground),
        displaySmall: AppTypography.displaySmall.copyWith(color: colorScheme.onBackground),
        headlineLarge: AppTypography.headlineLarge.copyWith(color: colorScheme.onBackground),
        headlineMedium: AppTypography.headlineMedium.copyWith(color: colorScheme.onBackground),
        headlineSmall: AppTypography.headlineSmall.copyWith(color: colorScheme.onBackground),
        titleLarge: AppTypography.titleLarge.copyWith(color: colorScheme.onBackground),
        titleMedium: AppTypography.titleMedium.copyWith(color: colorScheme.onBackground),
        titleSmall: AppTypography.titleSmall.copyWith(color: colorScheme.onBackground),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: colorScheme.onBackground),
        bodyMedium: AppTypography.bodyMedium.copyWith(color: colorScheme.onBackground),
        bodySmall: AppTypography.bodySmall.copyWith(color: colorScheme.onSurfaceVariant),
        labelLarge: AppTypography.labelLarge.copyWith(color: colorScheme.onBackground),
        labelMedium: AppTypography.labelMedium.copyWith(color: colorScheme.onBackground),
        labelSmall: AppTypography.labelSmall.copyWith(color: colorScheme.onSurfaceVariant),
      ),

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onBackground,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: colorScheme.onBackground,
        ),
      ),

      // ── Cards ──
      cardTheme: CardThemeData(
        elevation: isDark ? AppSpacing.elevationMd : AppSpacing.elevationSm,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),

      // ── Buttons ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: AppSpacing.elevationNone,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xlg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
          surfaceTintColor: Colors.transparent,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xlg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          side: BorderSide(color: colorScheme.outline, width: 1.5),
          foregroundColor: colorScheme.primary,
          textStyle: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          textStyle: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
        ),
      ),

      // ── Input Decoration ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(color: colorScheme.onSurfaceVariant),
        hintStyle: AppTypography.bodyMedium.copyWith(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
        errorStyle: AppTypography.bodySmall.copyWith(color: colorScheme.error),
      ),

      // ── Floating Action Buttons ──
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: AppSpacing.elevationLg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
      ),

      // ── Dividers ──
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ── Chips ──
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceVariant,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: AppTypography.labelMedium.copyWith(color: colorScheme.onSurface),
        secondaryLabelStyle: AppTypography.labelMedium.copyWith(color: colorScheme.onPrimaryContainer),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smd,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        side: BorderSide.none,
      ),

      // ── Navigation Bar ──
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        elevation: 8,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            );
          }
          return AppTypography.labelMedium.copyWith(
            color: colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: colorScheme.onPrimaryContainer,
              size: AppSpacing.iconLg,
            );
          }
          return IconThemeData(
            color: colorScheme.onSurfaceVariant,
            size: AppSpacing.iconLg,
          );
        }),
      ),

      // ── Dialogs ──
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        elevation: AppSpacing.elevationLg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
        ),
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: colorScheme.onSurface,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: colorScheme.onSurface,
        ),
      ),

      // ── Bottom Sheet ──
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        elevation: AppSpacing.elevationLg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXxl),
          ),
        ),
      ),

      // ── Progress Indicators ──
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primaryContainer,
        circularTrackColor: colorScheme.primaryContainer,
      ),

      // ── Sliders ──
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primaryContainer,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        valueIndicatorColor: colorScheme.primary,
        valueIndicatorTextStyle: AppTypography.bodySmall.copyWith(color: colorScheme.onPrimary),
      ),

      // ── Toggles (Switch, Checkbox, Radio) ──
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return colorScheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primaryContainer;
          return colorScheme.surfaceVariant;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.resolveWith((states) {
          return colorScheme.onPrimary;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm - 4),
        ),
        side: BorderSide(color: colorScheme.outline, width: 2),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return colorScheme.onSurfaceVariant;
        }),
      ),

      // ── Tab Bar ──
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
        unselectedLabelStyle: AppTypography.titleSmall,
      ),
    );
  }
}