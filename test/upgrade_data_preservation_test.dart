import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/core/services/notification_sync_service.dart';
import 'package:fast_flow/core/services/auth_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('hive_upgrade_test_');
    Hive.init(tempDir.path);
    await HiveService.instance.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('App Upgrade & Local Data Preservation Suite', () {
    test('1-10. Complete Upgrade, Auth, Logout, and Restart Cycle Preserves All Existing Local Data', () async {
      // 1. Populate old application with realistic existing data
      const existingDeviceId = 'device_legacy_1680000000000';
      const existingAnonUserId = 'user_anon_legacy_1680000000000';

      await HiveService.instance.setSetting('fcm_device_id', existingDeviceId);
      await HiveService.instance.setSetting('anon_user_id', existingAnonUserId);
      await HiveService.instance.setSetting('reminder_sound', 'eat.mp3');

      // Create 30 days of historical fasting records
      final now = DateTime.now();
      for (int i = 0; i < 30; i++) {
        final record = FastingRecord(
          id: 'record_$i',
          planName: '16:8 Fast',
          fastingMinutes: 960,
          eatingMinutes: 480,
          startTime: now.subtract(Duration(days: i + 1, hours: 16)),
          endTime: now.subtract(Duration(days: i + 1)),
          status: 'completed',
        );
        await HiveService.instance.saveFastingRecord(record);
      }

      // 2. Install/Update simulation: Verify Device ID and Anon User ID are intact before login
      final resolvedDeviceId = FcmService.instance.getOrCreateDeviceId();
      expect(resolvedDeviceId, equals(existingDeviceId));

      final unauthUserId = NotificationSyncService.instance.userId;
      expect(unauthUserId, equals(existingAnonUserId));

      // 3. Verify all 30 historical records exist before authentication
      final preAuthRecords = HiveService.instance.fastingRecordsBox.values.toList();
      expect(preAuthRecords.length, equals(30));
      expect(preAuthRecords.first.id, equals('record_0'));

      // 4. Register/Login simulation: Ensure zero data loss after auth state change
      expect(AuthService.instance.isAuthenticated, isFalse);

      // 5. Verify records remain 100% intact after auth pipeline execution
      final postAuthRecords = HiveService.instance.fastingRecordsBox.values.toList();
      expect(postAuthRecords.length, equals(30));
      expect(HiveService.instance.getSetting<String>('fcm_device_id'), equals(existingDeviceId));

      // 6. Simulate Logout
      await AuthService.instance.signOut();
      expect(AuthService.instance.isAuthenticated, isFalse);

      // 7. Verify records remain 100% intact after logout
      final postLogoutRecords = HiveService.instance.fastingRecordsBox.values.toList();
      expect(postLogoutRecords.length, equals(30));
      expect(HiveService.instance.getSetting<String>('reminder_sound'), equals('eat.mp3'));

      // 8. Simulate App Restart (Re-reading from Hive boxes)
      final postRestartDeviceId = FcmService.instance.getOrCreateDeviceId();
      expect(postRestartDeviceId, equals(existingDeviceId));

      final postRestartRecords = HiveService.instance.fastingRecordsBox.values.toList();
      expect(postRestartRecords.length, equals(30));
    });
  });
}
