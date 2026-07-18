import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/data/services/hive_service.dart';

class FoodLogEntry {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double fat;
  final double carbs;
  final double fiber;
  final DateTime date;

  const FoodLogEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.fiber,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
      'fiber': fiber,
      'date': date.toIso8601String(),
    };
  }

  factory FoodLogEntry.fromMap(Map<String, dynamic> map) {
    return FoodLogEntry(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown Food',
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0.0,
      fiber: (map['fiber'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : DateTime.now(),
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

  Future<void> deleteFoodLog(String id) async {
    await HiveService.instance.deleteFoodLog(id);
    state = state.where((item) => item.id != id).toList();
  }
}

final foodLogsProvider = NotifierProvider<FoodLogsNotifier, List<FoodLogEntry>>(FoodLogsNotifier.new);
