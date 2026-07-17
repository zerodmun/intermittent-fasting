import 'package:fast_flow/features/fasting/models/fasting_record.dart';

/// Result of a streak calculation.
class StreakResult {
  final int currentStreak;
  final int longestStreak;

  const StreakResult({
    required this.currentStreak,
    required this.longestStreak,
  });
}

/// Calculates fasting streaks from a list of records.
///
/// A streak is defined as consecutive days with at least one
/// completed fasting session.
abstract final class StreakCalculator {
  static StreakResult calculate(List<FastingRecord> records) {
    if (records.isEmpty) {
      return const StreakResult(currentStreak: 0, longestStreak: 0);
    }

    // Get unique completed days, sorted descending
    final completedDays = <DateTime>{};
    for (final record in records) {
      if (record.status == 'completed' && record.endTime != null) {
        final day = DateTime(
          record.startTime.year,
          record.startTime.month,
          record.startTime.day,
        );
        completedDays.add(day);
      }
    }

    if (completedDays.isEmpty) {
      return const StreakResult(currentStreak: 0, longestStreak: 0);
    }

    final sortedDays = completedDays.toList()
      ..sort((a, b) => b.compareTo(a));

    // Calculate current streak (from today or yesterday backwards)
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 1;

    // Check if the most recent day is today or yesterday
    if (sortedDays.first == todayStart || sortedDays.first == yesterdayStart) {
      currentStreak = 1;
      for (int i = 1; i < sortedDays.length; i++) {
        final diff = sortedDays[i - 1].difference(sortedDays[i]).inDays;
        if (diff == 1) {
          currentStreak++;
        } else {
          break;
        }
      }
    }

    // Calculate longest streak
    for (int i = 1; i < sortedDays.length; i++) {
      final diff = sortedDays[i - 1].difference(sortedDays[i]).inDays;
      if (diff == 1) {
        tempStreak++;
      } else {
        longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;
        tempStreak = 1;
      }
    }
    longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;
    longestStreak =
        currentStreak > longestStreak ? currentStreak : longestStreak;

    return StreakResult(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
    );
  }
}
