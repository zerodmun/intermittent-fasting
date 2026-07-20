import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/data/services/hive_service.dart';

class FoodLogEntry {
  final String id;
  final DateTime date;
  final String foodName;
  final double serving;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime createdAt;

  const FoodLogEntry({
    required this.id,
    required this.date,
    required this.foodName,
    required this.serving,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.createdAt,
  });

  // Getter aliases for backward compatibility
  String get name => foodName;
  double get carbohydrates => carbs;
  double get servingAmount => serving;
  double get fiber => 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'foodName': foodName,
      'name': foodName, // compatibility
      'serving': serving,
      'servingAmount': serving, // compatibility
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'carbohydrates': carbs, // compatibility
      'fat': fat,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FoodLogEntry.fromMap(Map<String, dynamic> map) {
    return FoodLogEntry(
      id: map['id'] as String? ?? '',
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : DateTime.now(),
      foodName: map['foodName'] as String? ?? map['name'] as String? ?? 'Unknown Food',
      serving: (map['serving'] as num?)?.toDouble() ?? (map['servingAmount'] as num?)?.toDouble() ?? 1.0,
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? (map['carbohydrates'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : (map['date'] != null ? DateTime.parse(map['date'] as String) : DateTime.now()),
    );
  }
}

class FoodLogsNotifier extends Notifier<List<FoodLogEntry>> {
  @override
  List<FoodLogEntry> build() {
    final rawLogs = HiveService.instance.allFoodLogs;
    return rawLogs.map((m) => FoodLogEntry.fromMap(m)).toList();
  }

  Future<void> addFoodLog(FoodLogEntry entry) async {
    await HiveService.instance.saveFoodLog(entry.id, entry.toMap());
    state = [entry, ...state];
  }

  Future<void> updateFoodLog(FoodLogEntry entry) async {
    await HiveService.instance.saveFoodLog(entry.id, entry.toMap());
    state = state.map((item) => item.id == entry.id ? entry : item).toList();
  }

  Future<void> deleteFoodLog(String id) async {
    await HiveService.instance.deleteFoodLog(id);
    state = state.where((item) => item.id != id).toList();
  }
}

final foodLogsProvider = NotifierProvider<FoodLogsNotifier, List<FoodLogEntry>>(FoodLogsNotifier.new);
