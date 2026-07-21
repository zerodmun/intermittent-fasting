import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/features/food/data/models/food_log_entry.dart';

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
