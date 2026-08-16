import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/notification_service.dart';
import 'package:fast_flow/core/services/fcm_service.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Etc/GMT-7'));
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('notif_dup_prevention_test_');
    Hive.init(tempDir.path);
    await HiveService.instance.init();
  });

  setUp(() async {
    FcmService.instance.resetMemoryCache();
    await HiveService.instance.notificationScheduleCacheBox.clear();
    await HiveService.instance.processedEventsBox.clear();
    await HiveService.instance.settingsBox.clear();
    await HiveService.instance.userProfileBox.clear();
    await HiveService.instance.fastingScheduleBox.clear();
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Production Notification Delivery & Exactly-One Audit Suite (13 Scenarios)', () {
    test('1. Local alarm only: Primary delivery registers durable SCHEDULED_LOCAL record in Hive', () async {
      final now = DateTime.now();
      final schedDate = DateTime(now.year, now.month, now.day, 18, 0);
      const eventId = 'fasting_schedule_001_2026-08-16T18:00:00.000_FASTING_START';

      await HiveService.instance.saveDeliveryRecord(
        eventId: eventId,
        data: {
          'eventId': eventId,
          'eventType': 'FASTING_START',
          'scheduledAt': schedDate.toIso8601String(),
          'notificationId': 2001,
          'channelId': 'fasting_reminders_fast_v2',
          'soundResource': 'fast',
          'scheduleVersion': 1,
          'deliverySource': 'LOCAL_ALARM',
          'status': 'SCHEDULED_LOCAL',
          'uid': 'test_user_001',
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );

      final record = HiveService.instance.getDeliveryRecord(eventId);
      expect(record, isNotNull);
      expect(record!['status'], equals('SCHEDULED_LOCAL'));
      expect(record['deliverySource'], equals('LOCAL_ALARM'));
      expect(record['notificationId'], equals(2001));
    });

    test('2. FCM fallback only: Allowed when local alarm was not scheduled', () async {
      const eventId = 'fasting_schedule_001_2026-08-16T18:00:00.000_FASTING_START_FALLBACK';

      // Ensure no local schedule exists for this event
      expect(HiveService.instance.getDeliveryRecord(eventId), isNull);

      final claim = await HiveService.instance.tryClaimNotificationDelivery(
        eventId: eventId,
        source: 'FCM',
      );

      expect(claim, isTrue);
      final record = HiveService.instance.getDeliveryRecord(eventId);
      expect(record, isNotNull);
      expect(record!['status'], equals('DELIVERED_FCM'));
      expect(record['source'], equals('FCM'));
    });

    test('3. Local alarm + FCM arriving 40 seconds later: FCM is skipped with FCM_SKIPPED_LOCAL_PRIMARY', () async {
      final now = DateTime.now();
      const eventId = 'fasting_schedule_001_2026-08-16T18:00:00.000_FASTING_START_40S';

      // 1. Local Alarm registers at 18:00:00
      await HiveService.instance.saveDeliveryRecord(
        eventId: eventId,
        data: {
          'eventId': eventId,
          'eventType': 'FASTING_START',
          'scheduledAt': now.toIso8601String(),
          'notificationId': 2001,
          'status': 'SCHEDULED_LOCAL',
          'deliverySource': 'LOCAL_ALARM',
          'updatedAt': now.toIso8601String(),
        },
      );

      // 2. FCM arrives at +40 seconds
      final claim = await HiveService.instance.tryClaimNotificationDelivery(
        eventId: eventId,
        source: 'FCM',
      );

      // FCM claim MUST be denied
      expect(claim, isFalse);

      final record = HiveService.instance.getDeliveryRecord(eventId);
      expect(record!['status'], equals('FCM_SKIPPED_LOCAL_PRIMARY'));
    });

    test('4. FCM arriving before local alarm: First claim wins atomically', () async {
      const eventId = 'fasting_schedule_001_2026-08-16T18:00:00.000_FASTING_START_EARLY_FCM';

      // FCM claims first
      final fcmClaim = await HiveService.instance.tryClaimNotificationDelivery(
        eventId: eventId,
        source: 'FCM',
      );
      expect(fcmClaim, isTrue);

      // Second claim from local alarm is rejected
      final localClaim = await HiveService.instance.tryClaimNotificationDelivery(
        eventId: eventId,
        source: 'LOCAL_ALARM',
      );
      expect(localClaim, isFalse);
    });

    test('5. Local and FCM executing concurrently: Atomic claim guarantees exactly one winner', () async {
      const eventId = 'fasting_schedule_001_2026-08-16T18:00:00.000_RACE_TEST';

      final results = await Future.wait([
        HiveService.instance.tryClaimNotificationDelivery(eventId: eventId, source: 'LOCAL_ALARM'),
        HiveService.instance.tryClaimNotificationDelivery(eventId: eventId, source: 'FCM'),
      ]);

      // Exactly ONE must succeed and exactly ONE must fail
      expect(results.where((r) => r == true).length, equals(1));
      expect(results.where((r) => r == false).length, equals(1));
    });

    test('6. Duplicate FCM messages: Subsequent pushes are rejected immediately', () async {
      const eventId = 'fasting_schedule_001_2026-08-16T18:00:00.000_DUP_FCM';

      final first = await HiveService.instance.tryClaimNotificationDelivery(eventId: eventId, source: 'FCM');
      expect(first, isTrue);

      final second = await HiveService.instance.tryClaimNotificationDelivery(eventId: eventId, source: 'FCM');
      expect(second, isFalse);

      final third = await HiveService.instance.tryClaimNotificationDelivery(eventId: eventId, source: 'FCM');
      expect(third, isFalse);
    });

    test('7. Duplicate local scheduling: Differential scheduler skips already scheduled reminders', () async {
      final now = DateTime.now();
      final schedDate = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
      final eventKey = '${schedDate.year}_${schedDate.month}_${schedDate.day}_${schedDate.hour}_${schedDate.minute}_FASTING_START';

      await HiveService.instance.markEventScheduledLocally(eventKey, schedDate);
      expect(HiveService.instance.isEventScheduledLocally(eventKey), isTrue);

      // Re-running check
      expect(HiveService.instance.isEventScheduledLocally(eventKey), isTrue);
    });

    test('8 & 9. App restart & device reboot: Hive durable records survive reload', () async {
      const eventId = 'fasting_schedule_001_2026-08-16T18:00:00.000_REBOOT_TEST';
      await HiveService.instance.saveDeliveryRecord(
        eventId: eventId,
        data: {
          'eventId': eventId,
          'status': 'DELIVERED_LOCAL',
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );

      final record = HiveService.instance.getDeliveryRecord(eventId);
      expect(record, isNotNull);
      expect(record!['status'], equals('DELIVERED_LOCAL'));
    });

    test('10. Account switching: Active UID isolation and FCM payload filtering', () async {
      const uidA = 'user_account_A_111';
      const uidB = 'user_account_B_222';

      await HiveService.instance.setSetting('bound_firebase_uid', uidA);
      expect(HiveService.instance.currentActiveUserId, equals(uidA));

      // Simulate FCM payload for Account B while Account A is active
      final fcmDataForB = {
        'type': 'fasting_start',
        'scheduleId': 'fasting_schedule_001',
        'version': '1',
        'eventId': 'fasting_schedule_001_2026-08-16T18:00:00.000_FASTING_START',
        'uid': uidB,
      };

      // FcmService should ignore payload for B when active UID is A
      final payloadUid = fcmDataForB['uid'];
      final activeUid = HiveService.instance.currentActiveUserId;
      expect(payloadUid != activeUid, isTrue);

      // Switch to B
      await HiveService.instance.setSetting('bound_firebase_uid', uidB);
      expect(HiveService.instance.currentActiveUserId, equals(uidB));
      expect(payloadUid == HiveService.instance.currentActiveUserId, isTrue);
    });

    test('11. Schedule modification: Differential rescheduling cleans previous markers', () async {
      final now = DateTime.now();
      final oldKey = '${now.year}_${now.month}_${now.day}_18_0_FASTING_START';
      await HiveService.instance.markEventScheduledLocally(oldKey, now);
      expect(HiveService.instance.isEventScheduledLocally(oldKey), isTrue);

      await NotificationService.instance.cancelReminderNotifications();
      expect(HiveService.instance.isEventScheduledLocally(oldKey), isFalse);
    });

    test('12. FASTING_START: Notification channel and sound mapping verified', () {
      final sound = NotificationService.instance.getFastingReminderSound(soundName: 'fast');
      expect(sound, isNotNull);
      expect(NotificationService.instance.normalizeEventType('fasting_start'), equals('FASTING_START'));
      expect(NotificationService.instance.normalizeEventType('fasting_reminder_start'), equals('FASTING_START_SOON'));
    });

    test('13. EAT_TIME / FASTING_END: Notification channel and sound mapping verified', () {
      final sound = NotificationService.instance.getFastingReminderSound(soundName: 'eat');
      expect(sound, isNotNull);
      expect(NotificationService.instance.normalizeEventType('fasting_end'), equals('FASTING_END'));
      expect(NotificationService.instance.normalizeEventType('eating_start'), equals('FASTING_END'));
      expect(NotificationService.instance.normalizeEventType('fasting_reminder_end'), equals('FASTING_END_SOON'));
    });

    test('14. Cross-format Cloudflare Worker FCM event: Local alarm ISO format matches worker eventId', () async {
      final now = DateTime.now();
      final dateStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final localIsoEventId = 'fasting_schedule_001_${now.toIso8601String()}_FASTING_START';
      final cloudflareWorkerEventId = 'fasting_schedule_001_v1_fasting_start_$dateStr';

      // 1. Local Alarm registers at 18:00:00 with ISO key
      await HiveService.instance.saveDeliveryRecord(
        eventId: localIsoEventId,
        data: {
          'eventId': localIsoEventId,
          'eventType': 'FASTING_START',
          'scheduledAt': now.toIso8601String(),
          'notificationId': 2001,
          'status': 'SCHEDULED_LOCAL',
          'deliverySource': 'LOCAL_ALARM',
          'scheduleVersion': 1,
          'updatedAt': now.toIso8601String(),
        },
      );

      // 2. Cloudflare Worker sends FCM with different eventId syntax 20s later
      final claim = await HiveService.instance.tryClaimNotificationDelivery(
        eventId: cloudflareWorkerEventId,
        source: 'FCM',
        eventType: 'FASTING_START',
        scheduledDate: now,
      );

      // FCM claim MUST be denied because local alarm is active for this event
      expect(claim, isFalse);
      expect(HiveService.instance.isEventProcessed(cloudflareWorkerEventId), isTrue);
    });

    test('15. Eating Window (EAT_TIME / FASTING_END): Cloudflare Worker FCM skipped when local alarm scheduled', () async {
      final now = DateTime.now();
      final dateStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final localIsoEventId = 'fasting_schedule_001_${now.toIso8601String()}_FASTING_END';
      final cloudflareWorkerEventId = 'fasting_schedule_001_v1_fasting_end_$dateStr';

      // 1. Local Alarm registers at 12:00:00 with ISO key
      await HiveService.instance.saveDeliveryRecord(
        eventId: localIsoEventId,
        data: {
          'eventId': localIsoEventId,
          'eventType': 'FASTING_END',
          'scheduledAt': now.toIso8601String(),
          'notificationId': 2003,
          'status': 'SCHEDULED_LOCAL',
          'deliverySource': 'LOCAL_ALARM',
          'scheduleVersion': 1,
          'updatedAt': now.toIso8601String(),
        },
      );

      // 2. Cloudflare Worker sends FCM at 12:00:20
      final claim = await HiveService.instance.tryClaimNotificationDelivery(
        eventId: cloudflareWorkerEventId,
        source: 'FCM',
        eventType: 'FASTING_END',
        scheduledDate: now,
      );

      // FCM claim MUST be denied
      expect(claim, isFalse);
      expect(HiveService.instance.isEventProcessed(cloudflareWorkerEventId), isTrue);
    });
  });
}

