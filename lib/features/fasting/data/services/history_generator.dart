import 'package:fast_flow/core/data/services/hive_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'timeline_generator.dart';

class HistoryGenerator {
  /// Scans the timeline of the past 7 days and auto-generates completed records for finished fasting sessions.
  static Future<void> autoGenerateHistory({
    required FastingSchedule schedule,
    required FastingRecord? Function(DateTime expectedStart) getRecordForSession,
  }) async {
    final now = DateTime.now();
    // Generate timeline sessions from 7 days ago until now
    final sessions = TimelineGenerator.generateTimeline(
      schedule: schedule,
      centerDate: now,
      daysBefore: 7,
      daysAfter: 0,
    );

    for (final session in sessions) {
      final expectedStart = session.expectedStart;
      final expectedEnd = session.expectedEnd;

      // Only generate history for sessions that have completely finished
      if (expectedEnd.isBefore(now)) {
        final existing = getRecordForSession(expectedStart);
        if (existing == null) {
          final durationMinutes = expectedEnd.difference(expectedStart).inMinutes;
          final record = FastingRecord(
            id: '${DateTime.now().millisecondsSinceEpoch}_${expectedStart.millisecondsSinceEpoch}',
            planName: 'Daily Schedule',
            fastingMinutes: durationMinutes,
            eatingMinutes: (24 * 60) - durationMinutes,
            startTime: expectedStart,
            endTime: expectedEnd,
            status: 'completed',
          );
          await HiveService.instance.saveFastingRecord(record);
        }
      }
    }
  }
}
