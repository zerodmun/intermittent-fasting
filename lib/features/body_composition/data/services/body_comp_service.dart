import 'dart:math';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';
import 'package:fast_flow/features/body_composition/domain/entities/body_comp_result.dart';
import 'package:fast_flow/features/body_composition/domain/entities/body_fat_category.dart';

/// Service class responsible for computing body composition parameters.
/// 
/// Calculations include Body Mass Index (BMI), Body Fat Percentage using the 
/// official U.S. Navy Method, Basal Metabolic Rate (BMR) using the Mifflin-St Jeor 
/// equation, Total Daily Energy Expenditure (TDEE), and Waist-to-Height ratio.
class BodyCompService {
  BodyCompService._();

  /// Calculates a comprehensive [BodyCompResult] for a user.
  /// 
  /// Uses [UserProfile] metadata (height, age, gender) and input parameters 
  /// such as [weightKg], [waistCm], [neckCm], and [hipCm] to estimate body composition.
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

    // BMI: weight (kg) / height (m)^2
    final bmi = weightKg / ((profile.heightCm / 100) * (profile.heightCm / 100));

    final hasBodyFat = isMale
        ? (waistCm != null && neckCm != null && waistCm > neckCm)
        : (waistCm != null && hipCm != null && neckCm != null && (waistCm + hipCm) > neckCm);

    // Body Fat % using U.S. Navy Method
    double bodyFatPercentage = 0.0;
    if (hasBodyFat) {
      if (isMale) {
        bodyFatPercentage = 495 /
            (1.0324 - 0.19077 * _log10(waistCm - neckCm) + 0.15456 * _log10(profile.heightCm)) -
            450;
      } else {
        bodyFatPercentage = 495 /
            (1.29579 - 0.35004 * _log10(waistCm + hipCm! - neckCm) + 0.22100 * _log10(profile.heightCm)) -
            450;
      }
      bodyFatPercentage = bodyFatPercentage.clamp(3.0, 60.0);
    }

    // Lean & Fat Mass
    final fatMassKg = hasBodyFat ? weightKg * (bodyFatPercentage / 100) : 0.0;
    final leanBodyMassKg = hasBodyFat ? weightKg - fatMassKg : weightKg;

    // BMR (Mifflin-St Jeor)
    double bmr;
    if (isMale) {
      bmr = 10 * weightKg + 6.25 * profile.heightCm - 5 * profile.ageYears + 5;
    } else {
      bmr = 10 * weightKg + 6.25 * profile.heightCm - 5 * profile.ageYears - 161;
    }

    // TDEE (Moderate activity multiplier)
    final tdee = bmr * 1.375;

    // Waist-to-Height Ratio
    final double whtr = waistCm != null ? waistCm / profile.heightCm : 0.0;

    // Ideal Weight (Devine Formula)
    final heightInches = profile.heightCm / 2.54;
    final inchesOver5Feet = max(0.0, heightInches - 60.0);
    final double idealWeightKg;
    if (isMale) {
      idealWeightKg = 50.0 + (2.3 * inchesOver5Feet);
    } else {
      idealWeightKg = 45.5 + (2.3 * inchesOver5Feet);
    }

    // Healthy BF ranges & category
    final category = BodyFatCategory.fromBodyFatPercentage(bodyFatPercentage, g);
    final double bfMin = isMale ? 8.0 : 21.0;
    final double bfMax = isMale ? 20.0 : 33.0;
    final isInHealthyRange = bodyFatPercentage >= bfMin && bodyFatPercentage <= bfMax;

    return BodyCompResult(
      hasBodyFat: hasBodyFat,
      bodyFatPercentage: bodyFatPercentage,
      leanBodyMassKg: leanBodyMassKg,
      fatMassKg: fatMassKg,
      bmi: bmi,
      bmr: bmr,
      tdee: tdee,
      category: category,
      bodyFatCategory: category.label,
      healthyRangeMin: bfMin,
      healthyRangeMax: bfMax,
      isInHealthyRange: isInHealthyRange,
      waistToHeightRatio: whtr,
      idealWeightKg: idealWeightKg,
    );
  }

  static double _log10(double value) => (value <= 0) ? 0 : log(value) / 2.302585092994046;
}
