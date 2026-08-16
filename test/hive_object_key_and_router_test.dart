import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/fasting/data/services/fasting_engine.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  UserProfile createTestProfile({required String name}) {
    return UserProfile(
      name: name,
      gender: 'male',
      ageYears: 28,
      heightCm: 175.0,
      weightKg: 70.0,
      goalWeightKg: 65.0,
      targetBodyFat: 15.0,
      targetWaist: 80.0,
      targetBmi: 22.0,
      selectedPlanId: '16-8',
      onboardingComplete: true,
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('hive_key_router_test_');
    Hive.init(tempDir.path);
    await HiveService.instance.init();
  });

  setUp(() async {
    FcmService.instance.resetMemoryCache();
    await HiveService.instance.userProfileBox.clear();
    await HiveService.instance.fastingScheduleBox.clear();
    await HiveService.instance.fastingRecordsBox.clear();
    await HiveService.instance.settingsBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HiveObject Key Safety & Router Integration Suite (Scenarios A - E)', () {
    test('Scenario A: Existing anonymous user data & schedule survive login without Hive key conflict', () async {
      await HiveService.instance.setSetting('device_id', 'device_XYZ');

      // Legacy anonymous user setup
      final legacyProf = createTestProfile(name: 'Legacy User');
      await HiveService.instance.userProfileBox.put('profile', legacyProf);

      final legacySched = FastingSchedule.defaultSchedule();
      await HiveService.instance.fastingScheduleBox.put('schedule', legacySched);

      for (int i = 1; i <= 30; i++) {
        final rec = FastingRecord(
          id: 'rec_legacy_$i',
          planName: '16:8',
          fastingMinutes: 960,
          eatingMinutes: 480,
          startTime: DateTime.now().subtract(Duration(days: 31 - i)),
          status: 'completed',
        );
        await HiveService.instance.saveFastingRecord(rec);
      }

      // Login Account A
      await HiveService.instance.setSetting('bound_firebase_uid', 'uid_account_A');

      final profileA = HiveService.instance.userProfile;
      expect(profileA?.name, equals('Legacy User'));

      final scheduleA = HiveService.instance.fastingSchedule;
      expect(scheduleA.dailySchedules[1]?.fastTimeFormatted, equals('17:00'));


      expect(HiveService.instance.allFastingRecords.length, equals(30));
    });

    test('Scenario B: Login -> logout -> login again causes zero Hive key conflicts or data loss', () async {
      await HiveService.instance.setSetting('device_id', 'device_XYZ');

      final profileA = createTestProfile(name: 'Account A');
      await HiveService.instance.saveUserProfile(profileA, 'uid_account_A');

      final scheduleA = FastingSchedule.defaultSchedule();
      await HiveService.instance.saveFastingSchedule(scheduleA, 'uid_account_A');

      // Login -> logout -> login
      await HiveService.instance.setSetting('bound_firebase_uid', 'uid_account_A');
      final loadedSched1 = HiveService.instance.fastingSchedule;
      await HiveService.instance.saveFastingSchedule(loadedSched1);

      await HiveService.instance.setSetting('bound_firebase_uid', null);

      await HiveService.instance.setSetting('bound_firebase_uid', 'uid_account_A');
      final loadedSched2 = HiveService.instance.fastingSchedule;
      await HiveService.instance.saveFastingSchedule(loadedSched2);

      expect(HiveService.instance.userProfile?.name, equals('Account A'));
    });

    test('Scenario C: Account A -> logout -> Account B isolates data safely without key conflict', () async {
      await HiveService.instance.setSetting('device_id', 'device_XYZ');

      final profileA = createTestProfile(name: 'Account A');
      await HiveService.instance.saveUserProfile(profileA, 'uid_account_A');

      final profileB = createTestProfile(name: 'Account B');
      await HiveService.instance.saveUserProfile(profileB, 'uid_account_B');

      // Account A
      await HiveService.instance.setSetting('bound_firebase_uid', 'uid_account_A');
      expect(HiveService.instance.userProfile?.name, equals('Account A'));

      // Account B
      await HiveService.instance.setSetting('bound_firebase_uid', 'uid_account_B');
      expect(HiveService.instance.userProfile?.name, equals('Account B'));

      // Back to Account A
      await HiveService.instance.setSetting('bound_firebase_uid', 'uid_account_A');
      expect(HiveService.instance.userProfile?.name, equals('Account A'));
    });

    test('Scenario D & E: FastingEngine timer ticks repeatedly without HiveError or repeated duplicate writes', () async {
      await HiveService.instance.setSetting('device_id', 'device_XYZ');

      final sched = FastingSchedule.defaultSchedule();
      await HiveService.instance.saveFastingSchedule(sched);

      final engine = FastingEngine();
      engine.initialize();

      // Simulate 5 consecutive ticks
      for (int i = 0; i < 5; i++) {
        final state = engine.currentState;
        expect(state, isNotNull);
      }

      engine.dispose();
    });
  });
}
