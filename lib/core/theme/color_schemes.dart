import 'package:flutter/material.dart';

import 'package:fast_flow/core/constants/app_colors.dart';

/// Material 3 color schemes for light and dark themes.
abstract final class AppColorSchemes {
  static ColorScheme get light => ColorScheme.fromSeed(
        seedColor: AppColors.teal500,
        brightness: Brightness.light,
        primary: AppColors.teal500,
        onPrimary: Colors.white,
        secondary: AppColors.amber400,
        onSecondary: Colors.black,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
        error: AppColors.error,
        onError: Colors.white,
      );

  static ColorScheme get dark => ColorScheme.fromSeed(
        seedColor: AppColors.teal500,
        brightness: Brightness.dark,
        primary: AppColors.teal200,
        onPrimary: AppColors.teal700,
        secondary: AppColors.amber200,
        onSecondary: Colors.black,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
        error: AppColors.errorDark,
        onError: Colors.black,
      );
}
