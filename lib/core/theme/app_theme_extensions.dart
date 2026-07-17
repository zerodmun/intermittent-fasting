import 'package:flutter/material.dart';

@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  // Fasting semantic colors
  final Color fastingActive;
  final Color eatingActive;
  final Color preparingActive;
  final Color completedActive;

  // Gradients
  final LinearGradient fastingGradient;
  final LinearGradient eatingGradient;
  final LinearGradient preparingGradient;
  final LinearGradient completedGradient;

  const AppColorsExtension({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.fastingActive,
    required this.eatingActive,
    required this.preparingActive,
    required this.completedActive,
    required this.fastingGradient,
    required this.eatingGradient,
    required this.preparingGradient,
    required this.completedGradient,
  });

  @override
  AppColorsExtension copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? fastingActive,
    Color? eatingActive,
    Color? preparingActive,
    Color? completedActive,
    LinearGradient? fastingGradient,
    LinearGradient? eatingGradient,
    LinearGradient? preparingGradient,
    LinearGradient? completedGradient,
  }) {
    return AppColorsExtension(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      fastingActive: fastingActive ?? this.fastingActive,
      eatingActive: eatingActive ?? this.eatingActive,
      preparingActive: preparingActive ?? this.preparingActive,
      completedActive: completedActive ?? this.completedActive,
      fastingGradient: fastingGradient ?? this.fastingGradient,
      eatingGradient: eatingGradient ?? this.eatingGradient,
      preparingGradient: preparingGradient ?? this.preparingGradient,
      completedGradient: completedGradient ?? this.completedGradient,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) {
      return this;
    }
    return AppColorsExtension(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      fastingActive: Color.lerp(fastingActive, other.fastingActive, t)!,
      eatingActive: Color.lerp(eatingActive, other.eatingActive, t)!,
      preparingActive: Color.lerp(preparingActive, other.preparingActive, t)!,
      completedActive: Color.lerp(completedActive, other.completedActive, t)!,
      fastingGradient: LinearGradient.lerp(fastingGradient, other.fastingGradient, t)!,
      eatingGradient: LinearGradient.lerp(eatingGradient, other.eatingGradient, t)!,
      preparingGradient: LinearGradient.lerp(preparingGradient, other.preparingGradient, t)!,
      completedGradient: LinearGradient.lerp(completedGradient, other.completedGradient, t)!,
    );
  }
}
