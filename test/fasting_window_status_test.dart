import 'package:flutter_test/flutter_test.dart';
import 'package:fast_flow/features/fasting/data/services/session_resolver.dart';
import 'package:fast_flow/features/fasting/data/services/timeline_generator.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_state.dart';

void main() {
  group('Fasting Window Status & Transitions Test Suite', () {
    late FastingSchedule schedule;

    setUp(() {
      // Configure schedule: Fasting starts at 20:00, Eating starts at 12:00 for all days (16:8)
      final map = <int, DailySchedule>{};
      for (int i = 1; i <= 7; i++) {
        map[i] = DailySchedule(
          fastHour: 20,
          fastMin: 0,
          eatHour: 12,
          eatMin: 0,
        );
      }
      schedule = FastingSchedule(dailySchedules: map);
    });

    FastingState getStateForTime(DateTime targetTime) {
      final sessions = TimelineGenerator.generateTimeline(
        schedule: schedule,
        centerDate: targetTime,
        daysBefore: 3,
        daysAfter: 3,
      );

      return SessionResolver.resolveState(
        now: targetTime,
        sessions: sessions,
        getOverrideRecord: (_) => null,
        schedule: schedule,
      );
    }

    test('00:00 - Fasting Window (12h remaining until 12:00)', () {
      final now = DateTime(2026, 8, 16, 0, 0);
      final state = getStateForTime(now);

      expect(state.currentPhase, equals(FastingPhase.fasting));
      expect(state.status, equals(FastingStatus.fasting));
      expect(state.remaining.inHours, equals(12));
    });

    test('08:00 - Fasting Window (4h remaining until 12:00)', () {
      final now = DateTime(2026, 8, 16, 8, 0);
      final state = getStateForTime(now);

      expect(state.currentPhase, equals(FastingPhase.fasting));
      expect(state.status, equals(FastingStatus.fasting));
      expect(state.remaining.inHours, equals(4));
    });

    test('10:00 - Fasting Window (2h remaining until 12:00)', () {
      final now = DateTime(2026, 8, 16, 10, 0);
      final state = getStateForTime(now);

      expect(state.currentPhase, equals(FastingPhase.fasting));
      expect(state.status, equals(FastingStatus.fasting));
      expect(state.remaining.inHours, equals(2));
    });

    test('11:59 - Fasting Window (1m remaining until 12:00)', () {
      final now = DateTime(2026, 8, 16, 11, 59);
      final state = getStateForTime(now);

      expect(state.currentPhase, equals(FastingPhase.fasting));
      expect(state.status, equals(FastingStatus.fasting));
      expect(state.remaining.inMinutes, equals(1));
    });

    test('12:00 - Eating Window (8h remaining until 20:00)', () {
      final now = DateTime(2026, 8, 16, 12, 0);
      final state = getStateForTime(now);

      expect(state.currentPhase, equals(FastingPhase.eating));
      expect(state.status, equals(FastingStatus.eatingWindow));
      expect(state.remaining.inHours, equals(8));
    });

    test('14:00 - Eating Window (6h remaining until 20:00)', () {
      final now = DateTime(2026, 8, 16, 14, 0);
      final state = getStateForTime(now);

      expect(state.currentPhase, equals(FastingPhase.eating));
      expect(state.status, equals(FastingStatus.eatingWindow));
      expect(state.remaining.inHours, equals(6));
    });

    test('18:00 - Eating Window / Preparing (2h remaining until 20:00)', () {
      final now = DateTime(2026, 8, 16, 18, 0);
      final state = getStateForTime(now);

      expect(state.currentPhase, equals(FastingPhase.eating));
      expect(state.status, equals(FastingStatus.preparing));
      expect(state.remaining.inHours, equals(2));
    });

    test('19:59 - Eating Window / Preparing (1m remaining until 20:00)', () {
      final now = DateTime(2026, 8, 16, 19, 59);
      final state = getStateForTime(now);

      expect(state.currentPhase, equals(FastingPhase.eating));
      expect(state.status, equals(FastingStatus.preparing));
      expect(state.remaining.inMinutes, equals(1));
    });

    test('20:00 - Fasting Window (16h remaining until 12:00 tomorrow)', () {
      final now = DateTime(2026, 8, 16, 20, 0);
      final state = getStateForTime(now);

      expect(state.currentPhase, equals(FastingPhase.fasting));
      expect(state.status, equals(FastingStatus.fasting));
      expect(state.remaining.inHours, equals(16));
    });

    test('22:00 - Fasting Window (14h remaining until 12:00 tomorrow)', () {
      final now = DateTime(2026, 8, 16, 22, 0);
      final state = getStateForTime(now);

      expect(state.currentPhase, equals(FastingPhase.fasting));
      expect(state.status, equals(FastingStatus.fasting));
      expect(state.remaining.inHours, equals(14));
    });
  });
}
