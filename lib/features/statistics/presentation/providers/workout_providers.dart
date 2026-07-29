import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/features/statistics/domain/entities/workout_log.dart';

class WorkoutLogsNotifier extends Notifier<List<WorkoutLog>> {
  @override
  List<WorkoutLog> build() {
    return _fetchLogs();
  }

  List<WorkoutLog> _fetchLogs() {
    try {
      final rawLogs = HiveService.instance.allWorkoutLogs;
      final logs = rawLogs.map((map) => WorkoutLog.fromMap(map)).toList();
      logs.sort((a, b) => b.date.compareTo(a.date));
      return logs;
    } catch (_) {
      return [];
    }
  }

  void loadLogs() {
    state = _fetchLogs();
  }

  Future<void> addWorkoutLog(WorkoutLog log) async {
    await HiveService.instance.saveWorkoutLog(log.id, log.toMap());
    loadLogs();
  }

  Future<void> updateWorkoutLog(WorkoutLog log) async {
    await HiveService.instance.saveWorkoutLog(log.id, log.toMap());
    loadLogs();
  }

  Future<void> deleteWorkoutLog(String id) async {
    await HiveService.instance.deleteWorkoutLog(id);
    loadLogs();
  }
}

final workoutLogsProvider = NotifierProvider<WorkoutLogsNotifier, List<WorkoutLog>>(
  WorkoutLogsNotifier.new,
);

/// Computes cumulative workout-only statistics
final workoutStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final logs = ref.watch(workoutLogsProvider);

  final int totalWorkouts = logs.length;
  final int totalExercises = logs.fold(0, (sum, log) => sum + log.totalExercises);
  final int totalSets = logs.fold(0, (sum, log) => sum + log.totalSets);
  final double totalVolumeKg = logs.fold(0.0, (sum, log) => sum + log.totalVolumeKg);
  final double totalCaloriesBurned = logs.fold(0.0, (sum, log) => sum + log.estimatedCaloriesBurned);
  final int totalDurationMinutes = logs.fold(0, (sum, log) => sum + log.durationMinutes);

  final double averageDurationMinutes = logs.isEmpty
      ? 0.0
      : (totalDurationMinutes / logs.length);

  return {
    'totalWorkouts': totalWorkouts,
    'totalExercises': totalExercises,
    'totalSets': totalSets,
    'totalVolumeKg': totalVolumeKg,
    'totalCaloriesBurned': totalCaloriesBurned,
    'totalDurationMinutes': totalDurationMinutes,
    'averageDurationMinutes': averageDurationMinutes,
  };
});
