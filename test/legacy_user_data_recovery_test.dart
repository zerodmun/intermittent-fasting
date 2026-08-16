import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/core/services/user_data_migration_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  UserProfile createTestProfile({required String name, double heightCm = 175.0}) {
    return UserProfile(
      name: name,
      gender: 'male',
      ageYears: 28,
      heightCm: heightCm,
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
    tempDir = await Directory.systemTemp.createTemp('legacy_recovery_test_');
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
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Safe Legacy User Data Recovery & Account Claim Suite (14 Tests)', () {
    test('1. Legacy user_uppo data exists and is detected', () async {
      await HiveService.instance.setSetting('anon_user_id', 'user_uppo');
      final legacyProf = createTestProfile(name: 'Legacy User Uppo');
      await HiveService.instance.userProfileBox.put('profile', legacyProf);

      expect(HiveService.instance.hasUnclaimedLocalUserData(), isTrue);
      expect(UserDataMigrationService.instance.localUserId, equals('user_uppo'));
    });

    test('2 & 3. Legacy data is claimed by hrNMd82DO8hJdv8BIcoNSVsEOAh1 and 1-month history remains intact', () async {
      await HiveService.instance.setSetting('anon_user_id', 'user_uppo');
      final legacyProf = createTestProfile(name: 'Legacy User Uppo', heightCm: 178.0);
      await HiveService.instance.userProfileBox.put('profile', legacyProf);

      for (int i = 1; i <= 30; i++) {
        final record = FastingRecord(
          id: 'rec_legacy_day_$i',
          planName: '16:8',
          fastingMinutes: 960,
          eatingMinutes: 480,
          startTime: DateTime(2026, 7, i, 20, 0),
          status: 'completed',
        );
        await HiveService.instance.saveFastingRecord(record);
      }

      const targetUid = 'hrNMd82DO8hJdv8BIcoNSVsEOAh1';
      await UserDataMigrationService.instance.claimLocalDataForFirebaseUser(targetUid);

      expect(HiveService.instance.allFastingRecords.length, equals(30));
      expect(HiveService.instance.getSetting<String>('claimed_by_uid'), equals(targetUid));
      expect(HiveService.instance.getSetting<String>('legacy_user_id'), equals('user_uppo'));
      expect(HiveService.instance.getSetting<String>('migration_status'), equals('completed'));
    });

    test('4, 5, 6. Profile, Schedule, and Settings remain intact', () async {
      const targetUid = 'hrNMd82DO8hJdv8BIcoNSVsEOAh1';
      final legacyProf = createTestProfile(name: 'Legacy User Uppo', heightCm: 182.0);
      await HiveService.instance.userProfileBox.put('profile', legacyProf);

      final sched = FastingSchedule(
        dailySchedules: {
          1: DailySchedule(fastHour: 18, fastMin: 0, eatHour: 12, eatMin: 0),
        },
      );
      await HiveService.instance.fastingScheduleBox.put('schedule', sched);
      await HiveService.instance.setSetting('custom_theme_mode', 'dark');

      await UserDataMigrationService.instance.claimLocalDataForFirebaseUser(targetUid);

      expect(HiveService.instance.userProfile?.name, equals('Legacy User Uppo'));
      expect(HiveService.instance.userProfile?.heightCm, equals(182.0));
      expect(HiveService.instance.fastingSchedule.dailySchedules[1]?.fastHour, equals(18));
      expect(HiveService.instance.getSetting<String>('custom_theme_mode'), equals('dark'));
    });

    test('7 & 8. No duplicate user created and migration is idempotent', () async {
      const targetUid = 'hrNMd82DO8hJdv8BIcoNSVsEOAh1';
      final legacyProf = createTestProfile(name: 'Legacy User Uppo');
      await HiveService.instance.userProfileBox.put('profile', legacyProf);

      // Run 1
      await UserDataMigrationService.instance.claimLocalDataForFirebaseUser(targetUid);
      expect(HiveService.instance.knownAccounts.where((a) => a['uid'] == targetUid).length, equals(1));

      // Run 2
      await UserDataMigrationService.instance.claimLocalDataForFirebaseUser(targetUid);
      expect(HiveService.instance.knownAccounts.where((a) => a['uid'] == targetUid).length, equals(1));
    });

    test('9. Running migration twice produces the exact same record count', () async {
      const targetUid = 'hrNMd82DO8hJdv8BIcoNSVsEOAh1';
      for (int i = 1; i <= 5; i++) {
        final record = FastingRecord(
          id: 'rec_$i',
          planName: '16:8',
          fastingMinutes: 960,
          eatingMinutes: 480,
          startTime: DateTime.now().subtract(Duration(days: i)),
          status: 'completed',
        );
        await HiveService.instance.saveFastingRecord(record);
      }

      await UserDataMigrationService.instance.claimLocalDataForFirebaseUser(targetUid);
      expect(HiveService.instance.allFastingRecords.length, equals(5));

      await UserDataMigrationService.instance.claimLocalDataForFirebaseUser(targetUid);
      expect(HiveService.instance.allFastingRecords.length, equals(5));
    });

    test('10. Login skips onboarding after successful migration', () async {
      const targetUid = 'hrNMd82DO8hJdv8BIcoNSVsEOAh1';
      final legacyProf = createTestProfile(name: 'Legacy User Uppo');
      await HiveService.instance.userProfileBox.put('profile', legacyProf);

      await UserDataMigrationService.instance.claimLocalDataForFirebaseUser(targetUid);
      expect(HiveService.instance.hasCompletedOnboardingForUser(targetUid), isTrue);
    });

    test('11 & 12. Account B cannot access Account A data; switching A -> B -> A restores data', () async {
      const uidA = 'hrNMd82DO8hJdv8BIcoNSVsEOAh1';
      const uidB = 'uid_account_B_789';

      final profA = createTestProfile(name: 'Account A', heightCm: 180.0);
      await HiveService.instance.saveUserProfile(profA, uidA);

      final profB = createTestProfile(name: 'Account B', heightCm: 160.0);
      await HiveService.instance.saveUserProfile(profB, uidB);

      // Switch to A
      await UserDataMigrationService.instance.switchAccount(uidA);
      expect(HiveService.instance.userProfile?.name, equals('Account A'));
      expect(HiveService.instance.userProfile?.heightCm, equals(180.0));

      // Switch to B
      await UserDataMigrationService.instance.switchAccount(uidB);
      expect(HiveService.instance.userProfile?.name, equals('Account B'));
      expect(HiveService.instance.userProfile?.heightCm, equals(160.0));

      // Switch back to A
      await UserDataMigrationService.instance.switchAccount(uidA);
      expect(HiveService.instance.userProfile?.name, equals('Account A'));
      expect(HiveService.instance.userProfile?.heightCm, equals(180.0));
    });

    test('13. App restart preserves the migrated data', () async {
      const targetUid = 'hrNMd82DO8hJdv8BIcoNSVsEOAh1';
      await HiveService.instance.setSetting('bound_firebase_uid', targetUid);
      await HiveService.instance.setSetting('first_bound_uid', targetUid);

      final prof = createTestProfile(name: 'Restart User');
      await HiveService.instance.saveUserProfile(prof, targetUid);

      expect(HiveService.instance.currentActiveUserId, equals(targetUid));
      expect(HiveService.instance.userProfile?.name, equals('Restart User'));
    });

    test('14. Firestore sync does not overwrite valid local data with empty/default data', () async {
      const targetUid = 'hrNMd82DO8hJdv8BIcoNSVsEOAh1';
      final localProf = createTestProfile(name: 'Valid Local User', heightCm: 175.0);
      await HiveService.instance.saveUserProfile(localProf, targetUid);

      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: targetUid,
        email: 'user@example.com',
      );

      expect(HiveService.instance.userProfile?.name, equals('Valid Local User'));
      expect(HiveService.instance.userProfile?.heightCm, equals(175.0));
    });
  });
}
