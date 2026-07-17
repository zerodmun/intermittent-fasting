import 'package:flutter/material.dart';

enum BodyFatCategory {
  essentialFat,
  athlete,
  fitness,
  average,
  obese;

  static BodyFatCategory fromBodyFatPercentage(double bodyFatPercentage, String gender) {
    if (gender.toLowerCase() == 'male') {
      if (bodyFatPercentage <= 5) return BodyFatCategory.essentialFat;
      if (bodyFatPercentage <= 13) return BodyFatCategory.athlete;
      if (bodyFatPercentage <= 17) return BodyFatCategory.fitness;
      if (bodyFatPercentage <= 24) return BodyFatCategory.average;
      return BodyFatCategory.obese;
    } else {
      if (bodyFatPercentage <= 13) return BodyFatCategory.essentialFat;
      if (bodyFatPercentage <= 20) return BodyFatCategory.athlete;
      if (bodyFatPercentage <= 24) return BodyFatCategory.fitness;
      if (bodyFatPercentage <= 31) return BodyFatCategory.average;
      return BodyFatCategory.obese;
    }
  }
}

extension BodyFatCategoryExtension on BodyFatCategory {
  String get label {
    switch (this) {
      case BodyFatCategory.essentialFat:
        return 'Essential Fat';
      case BodyFatCategory.athlete:
        return 'Athlete';
      case BodyFatCategory.fitness:
        return 'Fitness';
      case BodyFatCategory.average:
        return 'Average';
      case BodyFatCategory.obese:
        return 'Obese';
    }
  }

  Color get color {
    switch (this) {
      case BodyFatCategory.essentialFat:
        return const Color(0xFF3B82F6); // Blue
      case BodyFatCategory.athlete:
        return const Color(0xFF10B981); // Green
      case BodyFatCategory.fitness:
        return const Color(0xFFEAB308); // Yellow
      case BodyFatCategory.average:
        return const Color(0xFFF97316); // Orange
      case BodyFatCategory.obese:
        return const Color(0xFFEF4444); // Red
    }
  }

  String getHealthyRange(String gender) {
    if (gender.toLowerCase() == 'male') {
      return '10% - 20%';
    } else {
      return '18% - 28%';
    }
  }
}
