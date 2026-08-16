import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/core/services/user_data_migration_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';
import 'package:fast_flow/features/auth/presentation/screens/account_screen.dart';

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
    tempDir = await Directory.systemTemp.createTemp('account_isolation_test_');
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

  group('Account Management, Switching, and Data Isolation Suite', () {
    test('Test 1: Existing Firebase Account -> Login directly opens Home with existing data', () async {
      await HiveService.instance.setSetting('device_id', 'device_123');

      final profileA = createTestProfile(name: 'Alice A', heightCm: 170.0);
      await HiveService.instance.saveUserProfile(profileA, 'uid_alice');

      expect(HiveService.instance.hasCompletedOnboardingForUser('uid_alice'), isTrue);

      await UserDataMigrationService.instance.switchAccount('uid_alice');
      expect(HiveService.instance.userProfile?.name, equals('Alice A'));
    });

    test('Test 2: Anonymous user with 1 month data -> Register -> 30-day data preserved, links to Account B, skips onboarding', () async {
      await HiveService.instance.setSetting('device_id', 'device_123');

      // 1. Create anonymous local data (1 month simulation)
      final localProf = createTestProfile(name: 'Offline User', heightCm: 180.0);
      await HiveService.instance.userProfileBox.put('profile', localProf);

      for (int i = 1; i <= 30; i++) {
        final record = FastingRecord(
          id: 'rec_day_$i',
          planName: '16:8',
          fastingMinutes: 960,
          eatingMinutes: 480,
          startTime: DateTime.now().subtract(Duration(days: 31 - i)),
          status: 'completed',
        );
        await HiveService.instance.saveFastingRecord(record);
      }

      expect(HiveService.instance.hasUnclaimedLocalUserData(), isTrue);

      // 2. Register Account B
      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: 'uid_Account_B',
        email: 'userB@example.com',
      );

      // 3. Verify Account B claimed data cleanly
      expect(HiveService.instance.userProfile?.name, equals('Offline User'));
      expect(HiveService.instance.userProfile?.heightCm, equals(180.0));
      expect(HiveService.instance.allFastingRecords.length, equals(30));
      expect(HiveService.instance.hasCompletedOnboardingForUser('uid_Account_B'), isTrue);
    });

    test('Test 3: New account with no local data -> triggers onboarding', () async {
      await HiveService.instance.setSetting('device_id', 'device_123');
      await HiveService.instance.setSetting('legacy_data_claimed', true);
      await HiveService.instance.setSetting('first_bound_uid', 'uid_first');

      expect(HiveService.instance.getUserProfileFor('uid_brand_new'), isNull);
      expect(HiveService.instance.hasCompletedOnboardingForUser('uid_brand_new'), isFalse);
    });

    test('Test 4: Switch accounts -> Account B data displayed, Account A not visible, data isolated', () async {
      await HiveService.instance.setSetting('device_id', 'device_123');

      // Setup Account A
      final profA = createTestProfile(name: 'John A', heightCm: 175.0);
      await HiveService.instance.saveUserProfile(profA, 'uid_A');
      await HiveService.instance.registerKnownAccount(uid: 'uid_A', email: 'john@example.com', displayName: 'John A');

      // Setup Account B
      final profB = createTestProfile(name: 'Test 2 B', heightCm: 165.0);
      await HiveService.instance.saveUserProfile(profB, 'uid_B');
      await HiveService.instance.registerKnownAccount(uid: 'uid_B', email: 'test2@example.com', displayName: 'Test 2 B');

      // Active Account A
      await UserDataMigrationService.instance.switchAccount('uid_A');
      expect(HiveService.instance.userProfile?.name, equals('John A'));
      expect(HiveService.instance.userProfile?.heightCm, equals(175.0));

      // Switch to Account B
      await UserDataMigrationService.instance.switchAccount('uid_B');
      expect(HiveService.instance.userProfile?.name, equals('Test 2 B'));
      expect(HiveService.instance.userProfile?.heightCm, equals(165.0));

      // Switch back to Account A
      await UserDataMigrationService.instance.switchAccount('uid_A');
      expect(HiveService.instance.userProfile?.name, equals('John A'));
    });

    test('Test 5: Logout and Login Account A again -> Account A data restored cleanly', () async {
      await HiveService.instance.setSetting('device_id', 'device_123');

      final profA = createTestProfile(name: 'John A', heightCm: 175.0);
      await HiveService.instance.saveUserProfile(profA, 'uid_A');

      // Logout
      await HiveService.instance.setSetting('bound_firebase_uid', null);

      // Login Account A again
      await UserDataMigrationService.instance.switchAccount('uid_A');
      expect(HiveService.instance.userProfile?.name, equals('John A'));
      expect(HiveService.instance.hasCompletedOnboardingForUser('uid_A'), isTrue);
    });

    test('Same deviceId is shared across multiple accounts without collision', () async {
      await HiveService.instance.setSetting('fcm_device_id', 'device_123');

      expect(FcmService.instance.getOrCreateDeviceId(), equals('device_123'));

      await HiveService.instance.registerKnownAccount(uid: 'uid_A', email: 'a@example.com');
      await HiveService.instance.registerKnownAccount(uid: 'uid_B', email: 'b@example.com');

      expect(HiveService.instance.knownAccounts.length, equals(2));
      expect(FcmService.instance.getOrCreateDeviceId(), equals('device_123'));
    });

    testWidgets('AccountScreen renders State A correctly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AccountScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No account connected'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
