class OfflineException implements Exception {
  final String message;
  const OfflineException([this.message = 'No internet connection.']);
  @override
  String toString() => message;
}

class FoodProduct {
  final String? barcode;
  final String name;
  final String brand;
  final String? imageUrl;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final String servingSize;
  final double fiber;

  const FoodProduct({
    this.barcode,
    required this.name,
    required this.brand,
    this.imageUrl,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.servingSize,
    this.fiber = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      'name': name,
      'brand': brand,
      'imageUrl': imageUrl,
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fat': fat,
      'servingSize': servingSize,
      'fiber': fiber,
    };
  }

  factory FoodProduct.fromMap(Map<String, dynamic> map) {
    return FoodProduct(
      barcode: map['barcode'] as String?,
      name: map['name'] as String? ?? 'Unknown Food',
      brand: map['brand'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      carbohydrates: (map['carbohydrates'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
      servingSize: map['servingSize'] as String? ?? '100g',
      fiber: (map['fiber'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
