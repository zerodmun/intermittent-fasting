import 'body_fat_category.dart';

class BodyCompResult {
  final double bodyFatPercentage;
  final double leanBodyMassKg;
  final double fatMassKg;
  final double bmi;
  final double bmr;
  final double tdee;
  final BodyFatCategory category;
  final String bodyFatCategory;

  final double? waistCm;
  final double? neckCm;
  final double? hipCm;
  final double? heightCm;
  final double? weightKg;
  final String? gender;
  final int? ageYears;

  BodyCompResult({
    required this.bodyFatPercentage,
    required this.leanBodyMassKg,
    required this.fatMassKg,
    required this.bmi,
    required this.bmr,
    required this.tdee,
    required this.category,
    required this.bodyFatCategory,
    this.waistCm,
    this.neckCm,
    this.hipCm,
    this.heightCm,
    this.weightKg,
    this.gender,
    this.ageYears,
  });

  double get categoryProgress {
    switch (category) {
      case BodyFatCategory.essentialFat:
        return 0.0;
      case BodyFatCategory.athlete:
        return 0.25;
      case BodyFatCategory.fitness:
        return 0.5;
      case BodyFatCategory.average:
        return 0.75;
      case BodyFatCategory.obese:
        return 1.0;
    }
  }

  String get healthyRange {
    if (gender?.toLowerCase() == 'male') {
      return 'Healthy male range: 14% - 24%';
    } else {
      return 'Healthy female range: 21% - 31%';
    }
  }

  double get bodyFatRangeMin {
    if (gender?.toLowerCase() == 'male') return 14.0;
    return 21.0;
  }

  double get bodyFatRangeMax {
    if (gender?.toLowerCase() == 'male') return 24.0;
    return 31.0;
  }

  bool get isInHealthyRange {
    return bodyFatPercentage >= bodyFatRangeMin && bodyFatPercentage <= bodyFatRangeMax;
  }
}