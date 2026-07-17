import 'dart:math';

import 'package:fast_flow/features/weight/domain/entities/body_comp_result.dart';
import 'package:fast_flow/features/weight/domain/entities/body_fat_category.dart';
import 'package:fast_flow/features/weight/domain/entities/weight_entry.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';

/// U.S. Navy Body Fat Formula Calculator
class BodyCompCalculator {
  static BodyCompResult calculate({
    required UserProfile profile,
    required double weightKg,
    double? waistCm,
    double? neckCm,
    double? hipCm,
    String? gender,
  }) {
    final g = gender ?? profile.gender;
    final isMale = g.toLowerCase() == 'male';

    // BMI
    final bmi = weightKg / ((profile.heightCm / 100) * (profile.heightCm / 100));

    // Body Fat % using U.S. Navy Method
    double bodyFatPercentage;
    if (isMale) {
      // Male: %BF = 495 / (1.0324 - 0.19077 * log10(waist - neck) + 0.15456 * log10(height)) - 450
      if (waistCm != null && neckCm != null) {
        final logWaistNeck = (waistCm - neckCm) <= 0 ? 1.0 : waistCm - neckCm;
        bodyFatPercentage = 495 /
            (1.0324 - 0.19077 * _log10(logWaistNeck) + 0.15456 * _log10(profile.heightCm)) -
            450;
      } else {
        bodyFatPercentage = 0;
      }
    } else {
      // Female: %BF = 495 / (1.29579 - 0.35004 * log10(waist + hip - neck) + 0.22100 * log10(height)) - 450
      if (waistCm != null && hipCm != null && neckCm != null) {
        final logWaistHipNeck = (waistCm + hipCm - neckCm) <= 0 ? 1.0 : waistCm + hipCm - neckCm;
        bodyFatPercentage = 495 /
            (1.29579 - 0.35004 * _log10(logWaistHipNeck) + 0.22100 * _log10(profile.heightCm)) -
            450;
      } else {
        bodyFatPercentage = 0;
      }
    }

    bodyFatPercentage = bodyFatPercentage.clamp(0.0, 60.0);

    // Lean Body Mass & Fat Mass
    final fatMassKg = weightKg * (bodyFatPercentage / 100);
    final leanBodyMassKg = weightKg - fatMassKg;

    // BMR (Mifflin-St Jeor)
    double bmr;
    if (isMale) {
      bmr = 88.362 + (13.397 * weightKg) + (4.799 * profile.heightCm) - (5.677 * profile.ageYears);
    } else {
      bmr = 447.593 + (9.247 * weightKg) + (3.098 * profile.heightCm) - (4.330 * profile.ageYears);
    }

    // TDEE (sedentary multiplier for safety)
    final tdee = bmr * 1.2;

    // Category
    final category = BodyFatCategory.fromBodyFatPercentage(bodyFatPercentage, g);

    return BodyCompResult(
      bodyFatPercentage: bodyFatPercentage,
      leanBodyMassKg: leanBodyMassKg,
      fatMassKg: fatMassKg,
      bmi: bmi,
      bmr: bmr,
      tdee: tdee,
      category: category,
      bodyFatCategory: category.label,
      waistCm: waistCm,
      neckCm: neckCm,
      hipCm: hipCm,
      heightCm: profile.heightCm,
      weightKg: weightKg,
      gender: g,
      ageYears: profile.ageYears,
    );
  }

  static double _log10(double value) => (value <= 0) ? 0 : log(value) / 2.302585092994046;
}