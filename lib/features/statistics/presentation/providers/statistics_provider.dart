import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/helpers/streak_calculator.dart';
import 'package:fast_flow/core/providers/app_providers.dart';



enum StatsPeriodMode { month, year }

class StatsPeriodFilter {
  final StatsPeriodMode mode;
  final int year;
  final int month; // 1..12

  const StatsPeriodFilter({
    required this.mode,
    required this.year,
    required this.month,
  });

  StatsPeriodFilter copyWith({
    StatsPeriodMode? mode,
    int? year,
    int? month,
  }) {
    return StatsPeriodFilter(
      mode: mode ?? this.mode,
      year: year ?? this.year,
      month: month ?? this.month,
    );
  }
}

class StatsPeriodFilterNotifier extends Notifier<StatsPeriodFilter> {
  @override
  StatsPeriodFilter build() {
    final now = DateTime.now();
    return StatsPeriodFilter(
      mode: StatsPeriodMode.month,
      year: now.year,
      month: now.month,
    );
  }

  void setMode(StatsPeriodMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setYear(int year) {
    state = state.copyWith(year: year);
  }

  void setMonth(int month) {
    state = state.copyWith(month: month);
  }
}

final statsPeriodFilterProvider = NotifierProvider<StatsPeriodFilterNotifier, StatsPeriodFilter>(
  StatsPeriodFilterNotifier.new,
);

class PeriodStats {
  final Duration totalFastDuration;
  final Duration? longestFastDuration;
  final Duration? shortestFastDuration;
  final int totalFasts;
  final int skipCount;

  const PeriodStats({
    required this.totalFastDuration,
    this.longestFastDuration,
    this.shortestFastDuration,
    required this.totalFasts,
    required this.skipCount,
  });
}

final availableYearsProvider = Provider<List<int>>((ref) {
  final records = ref.watch(fastingRecordsProvider);
  final currentYear = DateTime.now().year;
  final set = <int>{currentYear};
  for (final r in records) {
    set.add(r.startTime.year);
  }
  final list = set.toList()..sort((a, b) => b.compareTo(a));
  return list;
});

final periodStatsProvider = Provider<PeriodStats>((ref) {
  final records = ref.watch(fastingRecordsProvider);
  final filter = ref.watch(statsPeriodFilterProvider);

  final periodRecords = records.where((r) {
    if (filter.mode == StatsPeriodMode.month) {
      return r.startTime.year == filter.year && r.startTime.month == filter.month;
    } else {
      return r.startTime.year == filter.year;
    }
  }).toList();

  final completed = periodRecords.where((r) => r.status == 'completed').toList();
  final skipped = periodRecords.where((r) => r.status == 'skipped').toList();

  Duration totalFastDuration = Duration.zero;
  Duration? longestFastDuration;
  Duration? shortestFastDuration;

  for (final r in completed) {
    final dur = r.actualDuration;
    totalFastDuration += dur;

    if (longestFastDuration == null || dur > longestFastDuration) {
      longestFastDuration = dur;
    }
    if (shortestFastDuration == null || dur < shortestFastDuration) {
      shortestFastDuration = dur;
    }
  }

  return PeriodStats(
    totalFastDuration: totalFastDuration,
    longestFastDuration: longestFastDuration,
    shortestFastDuration: shortestFastDuration,
    totalFasts: completed.length,
    skipCount: skipped.length,
  );
});


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
