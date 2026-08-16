import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/core/services/user_data_migration_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('device_binding_test_');
    Hive.init(tempDir.path);
    await HiveService.instance.init();
  });

  setUp(() async {
    FcmService.instance.resetMemoryCache();
    await HiveService.instance.settingsBox.clear();
    await HiveService.instance.fastingRecordsBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Device Binding & Identity Audit Suite (Tests 1 - 7)', () {
    test('TEST 1: Existing installation - deviceId, anon_user_id & local data preserved', () async {
      await HiveService.instance.setSetting('fcm_device_id', 'device_123');
      await HiveService.instance.setSetting('anon_user_id', 'anon_456');

      final record = FastingRecord(
        id: 'rec_001',
        planName: '16:8',
        fastingMinutes: 960,
        eatingMinutes: 480,
        startTime: DateTime.now().subtract(const Duration(days: 30)),
        status: 'completed',
      );
      await HiveService.instance.saveFastingRecord(record);

      expect(FcmService.instance.getOrCreateDeviceId(), equals('device_123'));
      expect(UserDataMigrationService.instance.localUserId, equals('anon_456'));
      expect(HiveService.instance.allFastingRecords.length, equals(1));
      expect(HiveService.instance.allFastingRecords.first.id, equals('rec_001'));
    });

    test('TEST 2: Logout preserves deviceId & local data without creating new anon ID', () async {
      await HiveService.instance.setSetting('fcm_device_id', 'device_123');
      await HiveService.instance.setSetting('anon_user_id', 'anon_456');
      await HiveService.instance.setSetting('bound_firebase_uid', 'user_A_123');

      // Simulate logout: reset bound session markers only
      await HiveService.instance.setSetting('bound_firebase_uid', null);
      await HiveService.instance.setSetting('migration_status', 'legacy_local_user');

      expect(FcmService.instance.getOrCreateDeviceId(), equals('device_123'));
      expect(UserDataMigrationService.instance.localUserId, equals('anon_456'));
      expect(UserDataMigrationService.instance.boundFirebaseUid, isNull);
    });

    test('TEST 3: Login User B on same device reuses device_123', () async {
      await HiveService.instance.setSetting('fcm_device_id', 'device_123');
      await HiveService.instance.setSetting('anon_user_id', 'anon_456');

      // User A logs out
      await HiveService.instance.setSetting('bound_firebase_uid', null);

      // User B logs in
      await HiveService.instance.setSetting('bound_firebase_uid', 'user_B_456');

      expect(FcmService.instance.getOrCreateDeviceId(), equals('device_123'));
      expect(UserDataMigrationService.instance.boundFirebaseUid, equals('user_B_456'));
    });

    test('TEST 4: Active device binding is tied to current bound account', () async {
      await HiveService.instance.setSetting('fcm_device_id', 'device_123');
      await HiveService.instance.setSetting('bound_firebase_uid', 'user_B_456');

      expect(UserDataMigrationService.instance.boundFirebaseUid, equals('user_B_456'));
      expect(FcmService.instance.getOrCreateDeviceId(), equals('device_123'));
    });

    test('TEST 5: Account data isolation - bound UID accurately differentiates active user', () async {
      await HiveService.instance.setSetting('bound_firebase_uid', 'user_A_123');
      expect(UserDataMigrationService.instance.boundFirebaseUid, equals('user_A_123'));

      await HiveService.instance.setSetting('bound_firebase_uid', 'user_B_456');
      expect(UserDataMigrationService.instance.boundFirebaseUid, equals('user_B_456'));
    });

    test('TEST 6: App restart - deviceId remains unchanged', () async {
      await HiveService.instance.setSetting('fcm_device_id', 'device_123');
      expect(FcmService.instance.getOrCreateDeviceId(), equals('device_123'));

      // Simulate app restart memory cache clear
      FcmService.instance.resetMemoryCache();
      expect(FcmService.instance.getOrCreateDeviceId(), equals('device_123'));
    });

    test('TEST 7: App update - legacy deviceId, anon_user_id & history remain intact', () async {
      // Clear primary key to simulate pure legacy app update
      await HiveService.instance.setSetting('fcm_device_id', null);
      await HiveService.instance.setSetting('device_id', 'device_legacy_999');
      await HiveService.instance.setSetting('anon_user_id', 'anon_legacy_888');

      final legacyRecord = FastingRecord(
        id: 'legacy_001',
        planName: '16:8',
        fastingMinutes: 960,
        eatingMinutes: 480,
        startTime: DateTime.now().subtract(const Duration(days: 10)),
        status: 'completed',
      );
      await HiveService.instance.saveFastingRecord(legacyRecord);

      expect(FcmService.instance.getOrCreateDeviceId(), equals('device_legacy_999'));
      expect(UserDataMigrationService.instance.localUserId, equals('anon_legacy_888'));
      expect(HiveService.instance.allFastingRecords.length, equals(1));
    });
  });
}
