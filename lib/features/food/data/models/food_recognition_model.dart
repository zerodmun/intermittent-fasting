class FoodRecognitionModel {
  final String name;
  final int estimatedWeightG;
  final int calories;
  final int protein;
  final int fat;
  final int carbs;
  final double confidence;

  FoodRecognitionModel({
    required this.name,
    required this.estimatedWeightG,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.confidence,
  });

  factory FoodRecognitionModel.fromJson(Map<String, dynamic> json) {
    return FoodRecognitionModel(
      name: json['name'] as String? ?? 'Unknown Food',
      estimatedWeightG: (json['estimated_weight_g'] as num?)?.toInt() ?? 0,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toInt() ?? 0,
      fat: (json['fat'] as num?)?.toInt() ?? 0,
      carbs: (json['carbs'] as num?)?.toInt() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'estimated_weight_g': estimatedWeightG,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
      'confidence': confidence,
    };
  }
}
