import 'package:flutter_test/flutter_test.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_state.dart';
import 'package:fast_flow/features/fasting/data/services/timeline_generator.dart';
import 'package:fast_flow/features/fasting/data/services/session_resolver.dart';

void main() {
  group('Timeline Fasting Engine Tests (TimelineSession)', () {
    late FastingSchedule schedule;

    setUp(() {
      // Friday: Fast starts at 16:00, eating starts at 11:00 (Overnight fast ends Saturday 11:00)
      // Saturday: Fast starts at 18:00, eating starts at 10:00 (Overnight fast ends Sunday 10:00)
      final Map<int, DailySchedule> schedules = {
        1: DailySchedule(fastHour: 17, fastMin: 0, eatHour: 9, eatMin: 0),
        2: DailySchedule(fastHour: 18, fastMin: 0, eatHour: 10, eatMin: 0),
        3: DailySchedule(fastHour: 16, fastMin: 0, eatHour: 8, eatMin: 0),
        4: DailySchedule(fastHour: 17, fastMin: 0, eatHour: 9, eatMin: 0),
        5: DailySchedule(fastHour: 16, fastMin: 0, eatHour: 11, eatMin: 0), // Friday
        6: DailySchedule(fastHour: 18, fastMin: 0, eatHour: 10, eatMin: 0), // Saturday
        7: DailySchedule(fastHour: 17, fastMin: 0, eatHour: 9, eatMin: 0),
      };
      schedule = FastingSchedule(dailySchedules: schedules);
    });

    test('Timeline generation produces sorted sessions with schedule isolation', () {
      final centerDate = DateTime(2026, 7, 18, 12, 0); // Saturday
      final sessions = TimelineGenerator.generateTimeline(
        schedule: schedule,
        centerDate: centerDate,
        daysBefore: 1,
        daysAfter: 1,
      );

      // Verify sessions are sorted chronologically by expectedStart
      for (int i = 0; i < sessions.length - 1; i++) {
        expect(sessions[i].expectedStart.isBefore(sessions[i + 1].expectedStart), isTrue);
      }

      // Find Friday's session (starts on Friday 17th)
      final friSession = sessions.firstWhere((s) => s.expectedStart.day == 17);
      expect(friSession.expectedStart, DateTime(2026, 7, 17, 16, 0));
      expect(friSession.expectedEnd, DateTime(2026, 7, 18, 11, 0)); // Ends Saturday 11:00 (Friday Eat)
      expect(friSession.weekday, 5);

      // Find Saturday's session (starts on Saturday 18th)
      final satSession = sessions.firstWhere((s) => s.expectedStart.day == 18);
      expect(satSession.expectedStart, DateTime(2026, 7, 18, 18, 0));
      expect(satSession.expectedEnd, DateTime(2026, 7, 19, 10, 0)); // Ends Sunday 10:00 (Saturday Eat)
      expect(satSession.weekday, 6);
    });

    test('Resolves state correctly during overnight fast crossing midnight', () {
      final centerDate = DateTime(2026, 7, 18, 12, 0); // Saturday
      final sessions = TimelineGenerator.generateTimeline(
        schedule: schedule,
        centerDate: centerDate,
        daysBefore: 2,
        daysAfter: 2,
      );

      // Saturday 08:30 is in Friday's overnight fast (started Friday 16:00, ends Saturday 11:00)
      final testTime = DateTime(2026, 7, 18, 8, 30);
      final resolved = SessionResolver.resolveState(
        now: testTime,
        sessions: sessions,
        getOverrideRecord: (_) => null,
        schedule: schedule,
      );

      expect(resolved.currentPhase, FastingPhase.fasting);
      expect(resolved.status, FastingStatus.fasting);
      expect(resolved.activeWindowStart, DateTime(2026, 7, 17, 16, 0));
      expect(resolved.activeWindowEnd, DateTime(2026, 7, 18, 11, 0));
      expect(resolved.elapsed, const Duration(hours: 16, minutes: 30));
      expect(resolved.remaining, const Duration(hours: 2, minutes: 30));
    });

    test('Resolves state correctly during eating window', () {
      final centerDate = DateTime(2026, 7, 18, 12, 0); // Saturday
      final sessions = TimelineGenerator.generateTimeline(
        schedule: schedule,
        centerDate: centerDate,
        daysBefore: 2,
        daysAfter: 2,
      );

      // Saturday 12:00 is in the eating window (after Friday session ends at Saturday 11:00, before Saturday starts at 18:00)
      final testTime = DateTime(2026, 7, 18, 12, 0);
      final resolved = SessionResolver.resolveState(
        now: testTime,
        sessions: sessions,
        getOverrideRecord: (_) => null,
        schedule: schedule,
      );

      expect(resolved.currentPhase, FastingPhase.eating);
      expect(resolved.status, FastingStatus.eatingWindow);
      expect(resolved.activeWindowStart, DateTime(2026, 7, 18, 11, 0));
      expect(resolved.activeWindowEnd, DateTime(2026, 7, 18, 18, 0));
    });

    test('Calculates remaining countdown directly from ActiveSession.expectedEnd and isolates weekday schedules', () {
      // Current Time: Saturday 10:38
      // Friday Schedule: Fast 16:00, Eat 15:00 (Fasting session ends Saturday 15:00)
      // Saturday Schedule: Fast 20:00, Eat 12:00 (Fasting session ends Sunday 12:00)
      final Map<int, DailySchedule> testSchedules = {
        1: DailySchedule(fastHour: 17, fastMin: 0, eatHour: 9, eatMin: 0),
        2: DailySchedule(fastHour: 18, fastMin: 0, eatHour: 10, eatMin: 0),
        3: DailySchedule(fastHour: 16, fastMin: 0, eatHour: 8, eatMin: 0),
        4: DailySchedule(fastHour: 17, fastMin: 0, eatHour: 9, eatMin: 0),
        5: DailySchedule(fastHour: 16, fastMin: 0, eatHour: 15, eatMin: 0), // Friday
        6: DailySchedule(fastHour: 20, fastMin: 0, eatHour: 12, eatMin: 0), // Saturday
        7: DailySchedule(fastHour: 17, fastMin: 0, eatHour: 9, eatMin: 0),
      };
      final testSchedule = FastingSchedule(dailySchedules: testSchedules);

      final centerDate = DateTime(2026, 7, 18, 12, 0); // Saturday
      final sessions = TimelineGenerator.generateTimeline(
        schedule: testSchedule,
        centerDate: centerDate,
        daysBefore: 2,
        daysAfter: 2,
      );

      final testTime = DateTime(2026, 7, 18, 10, 38);
      final resolved = SessionResolver.resolveState(
        now: testTime,
        sessions: sessions,
        getOverrideRecord: (_) => null,
        schedule: testSchedule,
      );

      // Expected Friday session end: Saturday 15:00. Remaining countdown: 4h 22m (from 10:38 to 15:00).
      expect(resolved.currentPhase, FastingPhase.fasting);
      expect(resolved.activeWindowStart, DateTime(2026, 7, 17, 16, 0));
      expect(resolved.activeWindowEnd, DateTime(2026, 7, 18, 15, 0));
      expect(resolved.remaining, const Duration(hours: 4, minutes: 22));

      // --- MATHEMATICAL PROOF OF ISOLATION ---
      // 1. Modify Saturday eating start to 10:00 (this is Saturday's schedule).
      testSchedules[6]!.eatHour = 10;
      final scheduleModifiedSat = FastingSchedule(dailySchedules: testSchedules);
      final sessionsModifiedSat = TimelineGenerator.generateTimeline(
        schedule: scheduleModifiedSat,
        centerDate: centerDate,
        daysBefore: 2,
        daysAfter: 2,
      );
      final resolvedModifiedSat = SessionResolver.resolveState(
        now: testTime,
        sessions: sessionsModifiedSat,
        getOverrideRecord: (_) => null,
        schedule: scheduleModifiedSat,
      );
      // Changing Saturday schedule MUST NOT change the countdown target (remains Saturday 15:00, remaining 4h 22m)
      expect(resolvedModifiedSat.activeWindowEnd, DateTime(2026, 7, 18, 15, 0));
      expect(resolvedModifiedSat.remaining, const Duration(hours: 4, minutes: 22));

      // 2. Modify Friday eating start to 14:00 (this is Friday's schedule).
      testSchedules[5]!.eatHour = 14;
      final scheduleModifiedFri = FastingSchedule(dailySchedules: testSchedules);
      final sessionsModifiedFri = TimelineGenerator.generateTimeline(
        schedule: scheduleModifiedFri,
        centerDate: centerDate,
        daysBefore: 2,
        daysAfter: 2,
      );
      final resolvedModifiedFri = SessionResolver.resolveState(
        now: testTime,
        sessions: sessionsModifiedFri,
        getOverrideRecord: (_) => null,
        schedule: scheduleModifiedFri,
      );
      // Changing Friday schedule MUST immediately change the countdown target (becomes Saturday 14:00, remaining 3h 22m)
      expect(resolvedModifiedFri.activeWindowEnd, DateTime(2026, 7, 18, 14, 0));
      expect(resolvedModifiedFri.remaining, const Duration(hours: 3, minutes: 22));
    });
  });
}
