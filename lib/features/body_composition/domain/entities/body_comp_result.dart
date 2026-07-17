import 'body_fat_category.dart';

class BodyCompResult {
  final bool hasBodyFat;
  final double bodyFatPercentage;
  final double leanBodyMassKg;
  final double fatMassKg;
  final double bmi;
  final double bmr;
  final double tdee;
  final BodyFatCategory category;
  final String bodyFatCategory;
  final double healthyRangeMin;
  final double healthyRangeMax;
  final bool isInHealthyRange;
  final double waistToHeightRatio;
  final double idealWeightKg;

  const BodyCompResult({
    required this.hasBodyFat,
    required this.bodyFatPercentage,
    required this.leanBodyMassKg,
    required this.fatMassKg,
    required this.bmi,
    required this.bmr,
    required this.tdee,
    required this.category,
    required this.bodyFatCategory,
    required this.healthyRangeMin,
    required this.healthyRangeMax,
    required this.isInHealthyRange,
    required this.waistToHeightRatio,
    required this.idealWeightKg,
  });
}
