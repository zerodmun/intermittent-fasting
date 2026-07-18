import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';

class TimelineSession {
  final DateTime expectedStart;
  final DateTime expectedEnd;
  final int weekday;

  TimelineSession({
    required this.expectedStart,
    required this.expectedEnd,
    required this.weekday,
  });

  @override
  String toString() => 'Session(Start: $expectedStart, End: $expectedEnd, Weekday: $weekday)';
}

class TimelineGenerator {
  /// Generates a sorted list of TimelineSessions for the given range of days.
  /// Each session is defined entirely by the weekday schedule on the day it starts.
  static List<TimelineSession> generateTimeline({
    required FastingSchedule schedule,
    required DateTime centerDate,
    int daysBefore = 7,
    int daysAfter = 14,
  }) {
    final List<TimelineSession> sessions = [];
    final centerDay = DateTime(centerDate.year, centerDate.month, centerDate.day);

    for (int offset = -daysBefore; offset <= daysAfter; offset++) {
      final targetDay = centerDay.add(Duration(days: offset));
      final daySched = schedule.getScheduleFor(targetDay.weekday);

      // Fast starts on targetDay at targetDay's fastHour:fastMin
      final fastStart = DateTime(
        targetDay.year,
        targetDay.month,
        targetDay.day,
        daySched.fastHour,
        daySched.fastMin,
      );

      // Fast ends at targetDay's eatHour:eatMin
      DateTime fastEnd = DateTime(
        targetDay.year,
        targetDay.month,
        targetDay.day,
        daySched.eatHour,
        daySched.eatMin,
      );

      // If eating starts before or at fasting start time, it means the fast crosses midnight,
      // so the eating starts on the next day!
      if (fastEnd.isBefore(fastStart) || fastEnd.isAtSameMomentAs(fastStart)) {
        final nextDay = targetDay.add(const Duration(days: 1));
        fastEnd = DateTime(
          nextDay.year,
          nextDay.month,
          nextDay.day,
          daySched.eatHour,
          daySched.eatMin,
        );
      }

      sessions.add(TimelineSession(
        expectedStart: fastStart,
        expectedEnd: fastEnd,
        weekday: targetDay.weekday,
      ));
    }

    // Sort sessions chronologically by expectedStart
    sessions.sort((a, b) => a.expectedStart.compareTo(b.expectedStart));
    return sessions;
  }
}
