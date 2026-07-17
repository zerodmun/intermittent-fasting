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

  int get index {
    switch (this) {
      case BodyFatCategory.essentialFat:
        return 0;
      case BodyFatCategory.athlete:
        return 1;
      case BodyFatCategory.fitness:
        return 2;
      case BodyFatCategory.average:
        return 3;
      case BodyFatCategory.obese:
        return 4;
    }
  }
}