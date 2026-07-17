/// Result of a BMI calculation.
class BmiResult {
  final double bmi;
  final String category;
  final int categoryIndex; // 0=underweight, 1=normal, 2=overweight, 3=obese

  const BmiResult({
    required this.bmi,
    required this.category,
    required this.categoryIndex,
  });
}

/// Utility for calculating Body Mass Index.
abstract final class BmiCalculator {
  static BmiResult calculate({
    required double weightKg,
    required double heightCm,
  }) {
    if (heightCm <= 0 || weightKg <= 0) {
      return const BmiResult(
        bmi: 0,
        category: 'Invalid',
        categoryIndex: -1,
      );
    }

    final heightM = heightCm / 100;
    final bmi = weightKg / (heightM * heightM);

    String category;
    int index;

    if (bmi < 18.5) {
      category = 'Underweight';
      index = 0;
    } else if (bmi < 25.0) {
      category = 'Normal';
      index = 1;
    } else if (bmi < 30.0) {
      category = 'Overweight';
      index = 2;
    } else {
      category = 'Obese';
      index = 3;
    }

    return BmiResult(
      bmi: double.parse(bmi.toStringAsFixed(1)),
      category: category,
      categoryIndex: index,
    );
  }
}
