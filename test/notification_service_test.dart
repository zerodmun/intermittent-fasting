import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:fast_flow/core/services/notification_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';

void main() {
  group('NotificationService Tests', () {
    setUpAll(() {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Etc/GMT-7'));
    });

    test('nextInstanceOfWeekday calculates target dates correctly', () {
      final now = tz.TZDateTime.now(tz.local);
      final service = NotificationService.instance;

      final mondayTarget = service.nextInstanceOfWeekday(1, 12, 0);
      expect(mondayTarget.weekday, equals(1));
      expect(mondayTarget.hour, equals(12));
      expect(mondayTarget.isAfter(now), isTrue);
    });

    group('Smart Notification Scheduling Calculations', () {
      late FastingSchedule defaultSchedule;

      setUp(() {
        final Map<int, DailySchedule> schedules = {};
        for (int i = 1; i <= 7; i++) {
          schedules[i] = DailySchedule(
            fastHour: 17,
            fastMin: 0,
            eatHour: 9,
            eatMin: 0,
          );
        }
        defaultSchedule = FastingSchedule(dailySchedules: schedules);
      });

      test('Case A: Start time moved earlier (into the past)', () {
        // Current time: 16:50
        final now = DateTime(2026, 7, 21, 16, 50);
        
        // Custom schedule where fast starts at 16:00 (which is in the past) and ends at 08:00 tomorrow
        final Map<int, DailySchedule> customSchedules = {};
        for (int i = 1; i <= 7; i++) {
          customSchedules[i] = DailySchedule(
            fastHour: 16,
            fastMin: 0,
            eatHour: 8,
            eatMin: 0,
          );
        }
        final schedule = FastingSchedule(dailySchedules: customSchedules);

        final service = NotificationService.instance;
        final list = service.calculateNotificationsToSchedule(
          schedule: schedule,
          now: now,
          getRecordForSession: (expectedStart) => null, // No manual override record yet
          fastingEnabled: true,
          eatingEnabled: true,
        );

        // Expect:
        // - Start Fasting notification (16:00 today) is in the past, so NOT scheduled.
        // - Eating notification (08:00 tomorrow) is in the future, so it IS scheduled.
        // - Future sessions' Start Fasting / Eating notifications are scheduled.
        
        final todayFastingStart = DateTime(2026, 7, 21, 16, 0);
        final todayFastingEnd = DateTime(2026, 7, 22, 8, 0);

        final hasStartToday = list.any((n) => n.title == 'Time to Fast' && n.scheduledDate == todayFastingStart);
        final hasEatToday = list.any((n) => n.title == 'Time to Eat' && n.scheduledDate == todayFastingEnd);

        expect(hasStartToday, isFalse, reason: 'Fasting start is in the past and should not be scheduled');
        expect(hasEatToday, isTrue, reason: 'Eating time is in the future and should be scheduled');
      });

      test('Case B: Start time in the future', () {
        // Current time: 21:30
        final now = DateTime(2026, 7, 21, 21, 30);
        
        // Fast starts at 22:00 today (future) and ends at 14:00 tomorrow
        final Map<int, DailySchedule> customSchedules = {};
        for (int i = 1; i <= 7; i++) {
          customSchedules[i] = DailySchedule(
            fastHour: 22,
            fastMin: 0,
            eatHour: 14,
            eatMin: 0,
          );
        }
        final schedule = FastingSchedule(dailySchedules: customSchedules);

        final service = NotificationService.instance;
        final list = service.calculateNotificationsToSchedule(
          schedule: schedule,
          now: now,
          getRecordForSession: (expectedStart) => null,
          fastingEnabled: true,
          eatingEnabled: true,
        );

        // Expect:
        // - Start Fasting notification at 22:00 is in the future, so it IS scheduled.
        // - Eating notification at 14:00 tomorrow is in the future, so it IS scheduled.
        
        final todayFastingStart = DateTime(2026, 7, 21, 22, 0);
        final todayFastingEnd = DateTime(2026, 7, 22, 14, 0);

        final hasStartToday = list.any((n) => n.title == 'Time to Fast' && n.scheduledDate == todayFastingStart);
        final hasEatToday = list.any((n) => n.title == 'Time to Eat' && n.scheduledDate == todayFastingEnd);

        expect(hasStartToday, isTrue, reason: 'Fasting start is in the future and should be scheduled');
        expect(hasEatToday, isTrue, reason: 'Eating time is in the future and should be scheduled');
      });

      test('Case C: Eating time changed', () {
        // Current time: 10:00, user is fasting (starts at 06:00, expected to end at 22:00)
        final now = DateTime(2026, 7, 21, 10, 0);
        
        // Initial schedule: Fast 06:00 to 22:00
        final Map<int, DailySchedule> customSchedules = {};
        for (int i = 1; i <= 7; i++) {
          customSchedules[i] = DailySchedule(
            fastHour: 6,
            fastMin: 0,
            eatHour: 22,
            eatMin: 0,
          );
        }
        final schedule = FastingSchedule(dailySchedules: customSchedules);

        final service = NotificationService.instance;
        final listBefore = service.calculateNotificationsToSchedule(
          schedule: schedule,
          now: now,
          getRecordForSession: (expectedStart) => null,
          fastingEnabled: true,
          eatingEnabled: true,
        );

        expect(listBefore.any((n) => n.title == 'Time to Eat' && n.scheduledDate == DateTime(2026, 7, 21, 22, 0)), isTrue);

        // User changes eat time to 20:00 (eating earlier)
        for (int i = 1; i <= 7; i++) {
          customSchedules[i] = DailySchedule(
            fastHour: 6,
            fastMin: 0,
            eatHour: 20,
            eatMin: 0,
          );
        }
        final updatedSchedule = FastingSchedule(dailySchedules: customSchedules);

        final listAfter = service.calculateNotificationsToSchedule(
          schedule: updatedSchedule,
          now: now,
          getRecordForSession: (expectedStart) => null,
          fastingEnabled: true,
          eatingEnabled: true,
        );

        // Previous Eating notification at 22:00 is replaced by new one at 20:00
        expect(listAfter.any((n) => n.title == 'Time to Eat' && n.scheduledDate == DateTime(2026, 7, 21, 22, 0)), isFalse);
        expect(listAfter.any((n) => n.title == 'Time to Eat' && n.scheduledDate == DateTime(2026, 7, 21, 20, 0)), isTrue);
      });

      test('Case D: Fasting duration changed', () {
        // Current time: 18:00. Fast starts at 17:00 (active), expected end at 09:00 tomorrow (16 hours duration)
        final now = DateTime(2026, 7, 21, 18, 0);

        final service = NotificationService.instance;
        final listBefore = service.calculateNotificationsToSchedule(
          schedule: defaultSchedule,
          now: now,
          getRecordForSession: (expectedStart) => null,
          fastingEnabled: true,
          eatingEnabled: true,
        );

        // Expected end: 09:00 tomorrow (July 22)
        expect(listBefore.any((n) => n.title == 'Time to Eat' && n.scheduledDate == DateTime(2026, 7, 22, 9, 0)), isTrue);

        // User changes fast to 20 hours (ends at 13:00 tomorrow instead)
        final Map<int, DailySchedule> customSchedules = {};
        for (int i = 1; i <= 7; i++) {
          customSchedules[i] = DailySchedule(
            fastHour: 17,
            fastMin: 0,
            eatHour: 13,
            eatMin: 0,
          );
        }
        final schedule20 = FastingSchedule(dailySchedules: customSchedules);

        final listAfter = service.calculateNotificationsToSchedule(
          schedule: schedule20,
          now: now,
          getRecordForSession: (expectedStart) => null,
          fastingEnabled: true,
          eatingEnabled: true,
        );

        // Previous end (09:00) is gone, replaced with new end (13:00)
        expect(listAfter.any((n) => n.title == 'Time to Eat' && n.scheduledDate == DateTime(2026, 7, 22, 9, 0)), isFalse);
        expect(listAfter.any((n) => n.title == 'Time to Eat' && n.scheduledDate == DateTime(2026, 7, 22, 13, 0)), isTrue);
      });

      test('Fasting session already finished (completed/skipped/cancelled) schedules no alarms for that session', () {
        // Current time: 20:00. Fast started at 17:00, expected to end at 09:00 tomorrow.
        final now = DateTime(2026, 7, 21, 20, 0);

        final service = NotificationService.instance;

        // Mock completed override record for today's session
        final completedRecord = FastingRecord(
          id: 'session_${DateTime(2026, 7, 21, 17, 0).millisecondsSinceEpoch}',
          planName: '16:8',
          fastingMinutes: 16 * 60,
          eatingMinutes: 8 * 60,
          startTime: DateTime(2026, 7, 21, 17, 0),
          endTime: DateTime(2026, 7, 21, 19, 0), // Completed early at 19:00
          status: 'completed',
        );

        final list = service.calculateNotificationsToSchedule(
          schedule: defaultSchedule,
          now: now,
          getRecordForSession: (expectedStart) {
            if (expectedStart == DateTime(2026, 7, 21, 17, 0)) {
              return completedRecord;
            }
            return null;
          },
          fastingEnabled: true,
          eatingEnabled: true,
        );

        // Today's fast is completed, so no Eating notification should be scheduled for today
        expect(list.any((n) => n.title == 'Time to Eat' && n.scheduledDate.year == 2026 && n.scheduledDate.month == 7 && n.scheduledDate.day == 22), isFalse);
        
        // But future sessions should still be scheduled
        expect(list.any((n) => n.title == 'Time to Fast' && n.scheduledDate == DateTime(2026, 7, 22, 17, 0)), isTrue);
      });

      test('Fasting session active (running) schedules Eating notification at expected end', () {
        // Current time: 18:00. Fast starts at 17:00 (active), expected end at 09:00 tomorrow.
        final now = DateTime(2026, 7, 21, 18, 0);

        final service = NotificationService.instance;

        final activeRecord = FastingRecord(
          id: 'session_${DateTime(2026, 7, 21, 17, 0).millisecondsSinceEpoch}',
          planName: '16:8',
          fastingMinutes: 16 * 60,
          eatingMinutes: 8 * 60,
          startTime: DateTime(2026, 7, 21, 17, 0),
          status: 'active',
        );

        final list = service.calculateNotificationsToSchedule(
          schedule: defaultSchedule,
          now: now,
          getRecordForSession: (expectedStart) {
            if (expectedStart == DateTime(2026, 7, 21, 17, 0)) {
              return activeRecord;
            }
            return null;
          },
          fastingEnabled: true,
          eatingEnabled: true,
        );

        // Should schedule Eating notification at expected end (09:00 tomorrow)
        expect(list.any((n) => n.title == 'Time to Eat' && n.scheduledDate == DateTime(2026, 7, 22, 9, 0)), isTrue);
      });

      test('No duplicate notification IDs and only future times scheduled', () {
        final now = DateTime(2026, 7, 21, 12, 0);
        final service = NotificationService.instance;
        final list = service.calculateNotificationsToSchedule(
          schedule: defaultSchedule,
          now: now,
          getRecordForSession: (expectedStart) => null,
        );

        final ids = list.map((n) => n.id).toList();
        final uniqueIds = ids.toSet();
        expect(ids.length, equals(uniqueIds.length), reason: 'All scheduled notification IDs must be unique');

        for (final n in list) {
          expect(n.scheduledDate.isAfter(now), isTrue, reason: 'Notifications must only be scheduled in the future');
        }
      });
    });
  });
}
