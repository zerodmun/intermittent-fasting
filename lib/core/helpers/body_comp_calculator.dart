import 'dart:math';

/// Represents all computed body composition results.
class BodyCompResult {
  final double bodyFatPercentage;
  final double leanBodyMassKg;
  final double fatMassKg;
  final double bmi;
  final double minIdealWeightKg;
  final double maxIdealWeightKg;
  final double waistToHeightRatio;
  final double bmr;
  final double tdee;
  final String bodyFatCategory;
  final int categoryIndex; // 0=essential, 1=athlete, 2=fitness, 3=average, 4=obese

  const BodyCompResult({
    required this.bodyFatPercentage,
    required this.leanBodyMassKg,
    required this.fatMassKg,
    required this.bmi,
    required this.minIdealWeightKg,
    required this.maxIdealWeightKg,
    required this.waistToHeightRatio,
    required this.bmr,
    required this.tdee,
    required this.bodyFatCategory,
    required this.categoryIndex,
  });
}

/// Helper for calculating all body composition metrics.
abstract final class BodyCompCalculator {
  static double _log10(double x) => log(x) / ln10;

  static BodyCompResult calculate({
    required String gender,
    required double heightCm,
    required double weightKg,
    required double waistCm,
    required double neckCm,
    double hipCm = 0.0,
    int ageYears = 25,
  }) {
    // ── BMI ──
    final heightM = heightCm / 100;
    final bmiVal = weightKg / (heightM * heightM);

    // ── Ideal Weight Range ──
    final minIdeal = 18.5 * (heightM * heightM);
    final maxIdeal = 24.9 * (heightM * heightM);

    // ── Waist to Height Ratio ──
    final whtr = waistCm / heightCm;

    // ── Basal Metabolic Rate (BMR) & TDEE ──
    double bmrVal;
    if (gender.toLowerCase() == 'female') {
      bmrVal = 10 * weightKg + 6.25 * heightCm - 5 * ageYears - 161;
    } else {
      bmrVal = 10 * weightKg + 6.25 * heightCm - 5 * ageYears + 5;
    }
    final tdeeVal = bmrVal * 1.375; // assume light activity level multiplier

    // ── Body Fat Percentage ──
    double bf = 0.0;
    try {
      if (gender.toLowerCase() == 'female') {
        final val = waistCm + hipCm - neckCm;
        if (val > 0) {
          final density = 1.29579 - 0.35004 * _log10(val) + 0.22100 * _log10(heightCm);
          bf = (495 / density) - 450;
        }
      } else {
        final val = waistCm - neckCm;
        if (val > 0) {
          final density = 1.0324 - 0.19077 * _log10(val) + 0.15456 * _log10(heightCm);
          bf = (495 / density) - 450;
        }
      }
    } catch (_) {}

    if (bf.isNaN || bf.isInfinite || bf < 0) bf = 0.0;

    // ── Lean / Fat Mass ──
    final fatMass = weightKg * (bf / 100);
    final leanMass = weightKg - fatMass;

    // ── Category ──
    String category = 'Unknown';
    int catIdx = -1;

    if (gender.toLowerCase() == 'female') {
      if (bf <= 13.0) {
        category = 'Essential Fat';
        catIdx = 0;
      } else if (bf <= 20.0) {
        category = 'Athlete';
        catIdx = 1;
      } else if (bf <= 24.0) {
        category = 'Fitness';
        catIdx = 2;
      } else if (bf <= 31.0) {
        category = 'Average';
        catIdx = 3;
      } else {
        category = 'Obese';
        catIdx = 4;
      }
    } else {
      if (bf <= 5.0) {
        category = 'Essential Fat';
        catIdx = 0;
      } else if (bf <= 13.0) {
        category = 'Athlete';
        catIdx = 1;
      } else if (bf <= 17.0) {
        category = 'Fitness';
        catIdx = 2;
      } else if (bf <= 24.0) {
        category = 'Average';
        catIdx = 3;
      } else {
        category = 'Obese';
        catIdx = 4;
      }
    }

    return BodyCompResult(
      bodyFatPercentage: double.parse(bf.toStringAsFixed(1)),
      leanBodyMassKg: double.parse(leanMass.toStringAsFixed(1)),
      fatMassKg: double.parse(fatMass.toStringAsFixed(1)),
      bmi: double.parse(bmiVal.toStringAsFixed(1)),
      minIdealWeightKg: double.parse(minIdeal.toStringAsFixed(1)),
      maxIdealWeightKg: double.parse(maxIdeal.toStringAsFixed(1)),
      waistToHeightRatio: double.parse(whtr.toStringAsFixed(2)),
      bmr: double.parse(bmrVal.toStringAsFixed(0)),
      tdee: double.parse(tdeeVal.toStringAsFixed(0)),
      bodyFatCategory: category,
      categoryIndex: catIdx,
    );
  }
}
