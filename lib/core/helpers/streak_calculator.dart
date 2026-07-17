import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';

class StreakResult {
  final int currentStreak;
  final int longestStreak;
  final int totalCompleted;
  final DateTime? lastCompletedDate;

  StreakResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalCompleted,
    this.lastCompletedDate,
  });
}

class StreakCalculator {
  static StreakResult calculate(List<FastingRecord> records) {
    if (records.isEmpty) {
      return StreakResult(
        currentStreak: 0,
        longestStreak: 0,
        totalCompleted: 0,
        lastCompletedDate: null,
      );
    }

    // Filter completed records and sort by date
    final completedRecords = records
        .where((r) => r.isCompleted)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (completedRecords.isEmpty) {
      return StreakResult(
        currentStreak: 0,
        longestStreak: 0,
        totalCompleted: 0,
        lastCompletedDate: null,
      );
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterday = todayDate.subtract(const Duration(days: 1));

    // Check if today is completed
    final isTodayCompleted = completedRecords.any((r) =>
        r.startTime.year == todayDate.year &&
        r.startTime.month == todayDate.month &&
        r.startTime.day == todayDate.day);

    // Check if yesterday is completed
    final isYesterdayCompleted = completedRecords.any((r) =>
        r.startTime.year == yesterday.year &&
        r.startTime.month == yesterday.month &&
        r.startTime.day == yesterday.day);

    // Calculate current streak
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;

    var checkDate = isTodayCompleted ? todayDate : yesterday;

    // Count consecutive days backward
    while (true) {
      final hasRecord = completedRecords.any((r) =>
          r.startTime.year == checkDate.year &&
          r.startTime.month == checkDate.month &&
          r.startTime.day == checkDate.day);

      if (hasRecord) {
        currentStreak++;
        tempStreak++;
        longestStreak = longestStreak > tempStreak ? longestStreak : tempStreak;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    // Continue scanning for longest streak in history
    var scanDate = checkDate;
    tempStreak = 0;
    while (scanDate.isAfter(completedRecords.first.startTime.subtract(const Duration(days: 365)))) {
      final hasRecord = completedRecords.any((r) =>
          r.startTime.year == scanDate.year &&
          r.startTime.month == scanDate.month &&
          r.startTime.day == scanDate.day);

      if (hasRecord) {
        tempStreak++;
        longestStreak = longestStreak > tempStreak ? longestStreak : tempStreak;
      } else {
        tempStreak = 0;
      }
      scanDate = scanDate.subtract(const Duration(days: 1));
    }

    return StreakResult(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalCompleted: completedRecords.length,
      lastCompletedDate: completedRecords.last.startTime,
    );
  }
}