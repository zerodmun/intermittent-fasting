import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/helpers/streak_calculator.dart';
import 'package:fast_flow/core/providers/app_providers.dart';

class StatsData {
  final int currentStreak;
  final int longestStreak;
  final double averageDurationMinutes;
  final double totalFastingHours;
  final int totalCompleted;
  final int totalSessions;
  final double completionRate;
  final List<double> weeklyData; // 7 values for Mon-Sun
  final List<double> monthlyData; // 30 values

  const StatsData({
    required this.currentStreak,
    required this.longestStreak,
    required this.averageDurationMinutes,
    required this.totalFastingHours,
    required this.totalCompleted,
    required this.totalSessions,
    required this.completionRate,
    required this.weeklyData,
    required this.monthlyData,
  });
}

final statisticsProvider = Provider<StatsData>((ref) {
  final records = ref.watch(fastingRecordsProvider);
  final today = ref.watch(currentDateProvider);
  final streak = StreakCalculator.calculate(records);

  final completed = records.where((r) => r.status == 'completed').toList();
  final totalSessions = records.length;
  final totalCompleted = completed.length;

  double completionRate = 0.0;
  if (totalSessions > 0) {
    completionRate = (totalCompleted / totalSessions) * 100;
  }

  double totalMinutes = 0.0;
  for (final r in completed) {
    totalMinutes += r.actualDuration.inMinutes;
  }

  final averageDurationMinutes = completed.isNotEmpty ? totalMinutes / completed.length : 0.0;
  final totalFastingHours = totalMinutes / 60.0;

  // Compute last 7 days chart data (Monday to Sunday of current week)
  final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
  final weeklyData = List<double>.generate(7, (index) {
    final day = startOfWeek.add(Duration(days: index));
    double hours = 0;
    for (final r in completed) {
      if (r.startTime.year == day.year && r.startTime.month == day.month && r.startTime.day == day.day) {
        hours += r.actualDuration.inMinutes / 60.0;
      }
    }
    return hours;
  });

  // Compute last 30 days chart data
  final monthlyData = List<double>.generate(30, (index) {
    final day = today.subtract(Duration(days: 29 - index));
    double hours = 0;
    for (final r in completed) {
      if (r.startTime.year == day.year && r.startTime.month == day.month && r.startTime.day == day.day) {
        hours += r.actualDuration.inMinutes / 60.0;
      }
    }
    return hours;
  });

  return StatsData(
    currentStreak: streak.currentStreak,
    longestStreak: streak.longestStreak,
    averageDurationMinutes: averageDurationMinutes,
    totalFastingHours: totalFastingHours,
    totalCompleted: totalCompleted,
    totalSessions: totalSessions,
    completionRate: completionRate,
    weeklyData: weeklyData,
    monthlyData: monthlyData,
  );
});
