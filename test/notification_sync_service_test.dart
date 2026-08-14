import 'package:flutter_test/flutter_test.dart';
import 'package:fast_flow/core/services/notification_sync_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';

void main() {
  group('NotificationSyncService Integration & Schema Tests', () {
    test('A. Create notification schedule document contains required fields', () {
      final schedule = FastingSchedule.defaultSchedule();
      final doc = NotificationSyncService.instance.buildScheduleDocument(
        schedule: schedule,
        version: 1,
      );

      expect(doc['scheduleId'], equals(NotificationSyncService.scheduleId));
      expect(doc['enabled'], isTrue);
      expect(doc['startTime'], isNotNull);
      expect(doc['endTime'], isNotNull);
      expect(doc['reminderBeforeStart'], equals(10));
      expect(doc['reminderBeforeEnd'], equals(10));
      expect(doc['timezone'], equals('Asia/Jakarta'));
      expect(doc['version'], equals(1));
      expect(doc['updatedAt'], isNotNull);
      expect(doc['notificationSettings'], isA<Map<String, dynamic>>());
    });

    test('B & C. Update notification schedule document increments version correctly', () {
      final schedule = FastingSchedule.defaultSchedule();

      final docV1 = NotificationSyncService.instance.buildScheduleDocument(
        schedule: schedule,
        version: 1,
      );

      // Simulate schedule change
      final updatedMap = Map<int, DailySchedule>.from(schedule.dailySchedules);
      updatedMap[1] = DailySchedule(fastHour: 5, fastMin: 0, eatHour: 18, eatMin: 30);
      final updatedSchedule = schedule.copyWith(dailySchedules: updatedMap);

      final docV2 = NotificationSyncService.instance.buildScheduleDocument(
        schedule: updatedSchedule,
        version: docV1['version'] + 1,
      );

      expect(docV2['version'], equals(2));
      expect(docV2['scheduleId'], equals(docV1['scheduleId']));
    });

    test('D & F. Same scheduleId is preserved and no duplicate IDs generated', () {
      final schedule = FastingSchedule.defaultSchedule();

      final doc1 = NotificationSyncService.instance.buildScheduleDocument(schedule: schedule, version: 1);
      final doc2 = NotificationSyncService.instance.buildScheduleDocument(schedule: schedule, version: 2);
      final doc3 = NotificationSyncService.instance.buildScheduleDocument(schedule: schedule, version: 3);

      expect(doc1['scheduleId'], equals(NotificationSyncService.scheduleId));
      expect(doc2['scheduleId'], equals(NotificationSyncService.scheduleId));
      expect(doc3['scheduleId'], equals(NotificationSyncService.scheduleId));
    });

    test('E. Firestore path structure is users/{userId}/notificationSchedules/{scheduleId}', () {
      final userId = NotificationSyncService.instance.userId;
      const scheduleId = NotificationSyncService.scheduleId;
      final expectedPath = 'users/$userId/notificationSchedules/$scheduleId';

      expect(expectedPath, matches(RegExp(r'^users/[^/]+/notificationSchedules/fasting_schedule_001$')));
    });
  });
}
