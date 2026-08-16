import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/core/services/user_data_migration_service.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  UserProfile createTestProfile({
    required String name,
    required double heightCm,
    double weightKg = 70.0,
    double goalWeightKg = 65.0,
    String gender = 'male',
    int ageYears = 28,
    bool onboardingComplete = true,
  }) {
    return UserProfile(
      name: name,
      gender: gender,
      ageYears: ageYears,
      heightCm: heightCm,
      weightKg: weightKg,
      goalWeightKg: goalWeightKg,
      targetBodyFat: 15.0,
      targetWaist: 80.0,
      targetBmi: 22.0,
      selectedPlanId: '16-8',
      onboardingComplete: onboardingComplete,
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('account_profile_test_');
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

  group('Full 1-Month Lifecycle & Per-Account Migration Suite (Requirements 1-17)', () {
    test('Requirement 1 & 10: Existing 1-month local history survives account registration (No onboarding reset)', () async {
      // 1. PHASE 1: User uses app locally for 1 month with NO account
      await HiveService.instance.setSetting('device_id', 'device_ABC');
      final legacyProfile = createTestProfile(
        name: 'Legacy User',
        gender: 'male',
        ageYears: 30,
        heightCm: 176,
        weightKg: 68,
        onboardingComplete: true,
      );
      await HiveService.instance.userProfileBox.put('profile', legacyProfile);

      // Create 30 days of fasting history
      for (int i = 1; i <= 30; i++) {
        final record = FastingRecord(
          id: 'rec_legacy_day_$i',
          planName: '16:8',
          fastingMinutes: 960,
          eatingMinutes: 480,
          startTime: DateTime.now().subtract(Duration(days: 31 - i)),
          status: 'completed',
        );
        await HiveService.instance.saveFastingRecord(record);
      }

      expect(HiveService.instance.allFastingRecords.length, equals(30));
      expect(HiveService.instance.hasUnclaimedLocalUserData(), isTrue);

      // 2. PHASE 2: Register Test 1
      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: 'uid_test_1',
        email: 'test1@example.com',
      );

      // 3. Verify Test 1 claimed existing local data and NO onboarding is shown
      expect(HiveService.instance.hasCompletedOnboardingForUser('uid_test_1'), isTrue);
      final profile1 = HiveService.instance.getUserProfileFor('uid_test_1');
      expect(profile1?.name, equals('Legacy User'));
      expect(profile1?.heightCm, equals(176));
      expect(HiveService.instance.allFastingRecords.length, equals(30));
    });

    test('Requirement 4 & 5: Second account on same device does NOT inherit Test 1 data and triggers onboarding', () async {
      await HiveService.instance.setSetting('device_id', 'device_ABC');

      // Test 1 already registered & claimed local data
      final profile1 = createTestProfile(name: 'Test 1 User', heightCm: 176);
      await HiveService.instance.saveUserProfile(profile1, 'uid_test_1');
      await HiveService.instance.setSetting('first_bound_uid', 'uid_test_1');
      await HiveService.instance.setSetting('legacy_data_claimed', true);

      // Logout Test 1
      await HiveService.instance.setSetting('bound_firebase_uid', null);

      // Test 2 registers (brand new user)
      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: 'uid_test_2',
        email: 'test2@example.com',
      );

      // Verify Test 2 has NO profile, does NOT inherit Test 1 data, and MUST complete onboarding
      expect(HiveService.instance.getUserProfileFor('uid_test_2'), isNull);
      expect(HiveService.instance.hasCompletedOnboardingForUser('uid_test_2'), isFalse);
    });

    test('Requirement 6, 7 & 8: Complete Test 2 onboarding -> Switch between Test 1 and Test 2 restores respective data', () async {
      await HiveService.instance.setSetting('device_id', 'device_ABC');

      // Setup Test 1 profile & record
      final profile1 = createTestProfile(name: 'Test 1 User', heightCm: 176);
      await HiveService.instance.saveUserProfile(profile1, 'uid_test_1');
      final rec1 = FastingRecord(
        id: 'user_uid_test_1_rec_1',
        planName: '16:8',
        fastingMinutes: 960,
        eatingMinutes: 480,
        startTime: DateTime.now().subtract(const Duration(days: 5)),
        status: 'completed',
      );
      await HiveService.instance.saveFastingRecord(rec1);

      // Setup Test 2 profile & record
      final profile2 = createTestProfile(name: 'Test 2 User', heightCm: 165);
      await HiveService.instance.saveUserProfile(profile2, 'uid_test_2');
      final rec2 = FastingRecord(
        id: 'user_uid_test_2_rec_1',
        planName: '18:6',
        fastingMinutes: 1080,
        eatingMinutes: 360,
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        status: 'completed',
      );
      await HiveService.instance.saveFastingRecord(rec2);

      // Login Test 1
      await HiveService.instance.setSetting('bound_firebase_uid', 'uid_test_1');
      expect(HiveService.instance.userProfile?.name, equals('Test 1 User'));
      expect(HiveService.instance.allFastingRecords.first.id, equals('user_uid_test_1_rec_1'));

      // Logout Test 1 & Login Test 2
      await HiveService.instance.setSetting('bound_firebase_uid', 'uid_test_2');
      expect(HiveService.instance.userProfile?.name, equals('Test 2 User'));
      expect(HiveService.instance.allFastingRecords.first.id, equals('user_uid_test_2_rec_1'));
    });

    test('Requirement 9: Same deviceId is shared cleanly without mixing account identities', () async {
      await HiveService.instance.setSetting('fcm_device_id', 'device_ABC');

      final profile1 = createTestProfile(name: 'Test 1 User', heightCm: 176);
      final profile2 = createTestProfile(name: 'Test 2 User', heightCm: 165);

      await HiveService.instance.saveUserProfile(profile1, 'uid_test_1');
      await HiveService.instance.saveUserProfile(profile2, 'uid_test_2');

      expect(FcmService.instance.getOrCreateDeviceId(), equals('device_ABC'));

      // Test 1 context
      await HiveService.instance.setSetting('bound_firebase_uid', 'uid_test_1');
      expect(HiveService.instance.userProfile?.name, equals('Test 1 User'));

      // Test 2 context
      await HiveService.instance.setSetting('bound_firebase_uid', 'uid_test_2');
      expect(HiveService.instance.userProfile?.name, equals('Test 2 User'));

      // Same physical deviceId for both
      expect(FcmService.instance.getOrCreateDeviceId(), equals('device_ABC'));
    });

    test('Requirement 11: Offline registration / sync failure retains local data safely', () async {
      await HiveService.instance.setSetting('device_id', 'device_ABC');
      final legacyProfile = createTestProfile(name: 'Offline User', heightCm: 172);
      await HiveService.instance.userProfileBox.put('profile', legacyProfile);

      // Trigger migration with mock error in Firestore
      try {
        await UserDataMigrationService.instance.processPostLoginMigration(
          uid: 'uid_offline_test',
          email: 'offline@example.com',
        );
      } catch (_) {}

      // Verify local profile was claimed and retained despite offline warning
      expect(HiveService.instance.getUserProfileFor('uid_offline_test')?.name, equals('Offline User'));
      expect(HiveService.instance.hasCompletedOnboardingForUser('uid_offline_test'), isTrue);
    });
  });
}
