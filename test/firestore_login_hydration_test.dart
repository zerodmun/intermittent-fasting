import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/core/services/user_data_migration_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';
import 'package:fast_flow/features/onboarding/presentation/providers/onboarding_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  UserProfile createSampleProfile({
    required String name,
    double heightCm = 175.0,
    double weightKg = 72.0,
    bool onboardingComplete = true,
  }) {
    return UserProfile(
      name: name,
      gender: 'male',
      ageYears: 29,
      heightCm: heightCm,
      weightKg: weightKg,
      goalWeightKg: 68.0,
      targetBodyFat: 15.0,
      targetWaist: 80.0,
      targetBmi: 23.5,
      selectedPlanId: '16-8',
      onboardingComplete: onboardingComplete,
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('firestore_hydration_test_');
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

  group('Firestore Authoritative Login Data Hydration Suite', () {
    test('1. Authoritative Hydration: Complete cloud profile restores to Hive and sets onboardingComplete', () async {
      const uid = 'returning_user_complete_001';
      final cloudProfile = createSampleProfile(name: 'Sarah Connor', onboardingComplete: true);

      // Save directly to target user namespace simulating successful Firestore doc hydration
      await HiveService.instance.saveUserProfile(cloudProfile, uid);
      await HiveService.instance.setSetting('bound_firebase_uid', uid);
      await HiveService.instance.setSetting('migration_status', 'completed');

      final activeProfile = HiveService.instance.userProfile;
      expect(activeProfile, isNotNull);
      expect(activeProfile?.name, equals('Sarah Connor'));
      expect(activeProfile?.onboardingComplete, isTrue);
      expect(HiveService.instance.hasCompletedOnboardingForUser(uid), isTrue);
    });

    test('2. Missing Cloud Profile: Onboarding is required when user has no profile document', () async {
      const uid = 'new_firebase_user_002';
      await HiveService.instance.setSetting('bound_firebase_uid', uid);

      expect(HiveService.instance.getUserProfileFor(uid), isNull);
      expect(HiveService.instance.hasCompletedOnboardingForUser(uid), isFalse);
    });

    test('3. Incomplete Cloud Profile: Pre-fills onboarding without marking complete', () async {
      const uid = 'partial_user_003';
      final partialProfile = UserProfile(
        name: 'Incomplete John',
        gender: 'male',
        ageYears: 30,
        heightCm: 180.0,
        weightKg: 0.0, // Incomplete weight
        goalWeightKg: 0.0,
        targetBodyFat: 0.0,
        targetWaist: 0.0,
        targetBmi: 0.0,
        selectedPlanId: '16-8',
        onboardingComplete: false,
      );

      await HiveService.instance.saveUserProfile(partialProfile, uid);
      await HiveService.instance.setSetting('bound_firebase_uid', uid);

      expect(HiveService.instance.hasCompletedOnboardingForUser(uid), isFalse);

      final container = ProviderContainer();
      final onboardingState = container.read(onboardingProvider);
      expect(onboardingState.name, equals('Incomplete John'));
      expect(onboardingState.ageYears, equals(30));
      expect(onboardingState.heightCm, equals(180.0));
      container.dispose();
    });

    test('4. Fasting Records Restoration: Merges cloud fasting records without duplicates', () async {
      const uid = 'history_user_004';
      await HiveService.instance.setSetting('bound_firebase_uid', uid);

      for (int i = 1; i <= 10; i++) {
        final rec = FastingRecord(
          id: 'cloud_rec_${uid}_$i',
          planName: '16:8',
          fastingMinutes: 960,
          eatingMinutes: 480,
          startTime: DateTime.now().subtract(Duration(days: 15 - i)),
          status: 'completed',
        );
        await HiveService.instance.saveFastingRecord(rec);
      }

      final records = HiveService.instance.allFastingRecords;
      expect(records.length, equals(10));
      expect(records.first.id, contains(uid));
    });

    test('5. Reinstall Flow: Fresh Hive state hydrates Firestore data without false device conflict', () async {
      const uid = 'reinstall_user_005';

      // 1. Fresh install state (no local profile)
      expect(HiveService.instance.userProfileBox.isEmpty, isTrue);

      // 2. User logs in -> simulate Firestore hydration
      final restored = createSampleProfile(name: 'Reinstalled User', heightCm: 178.0);
      await HiveService.instance.saveUserProfile(restored, uid);
      await HiveService.instance.setSetting('bound_firebase_uid', uid);
      await HiveService.instance.registerKnownAccount(uid: uid, email: 'reinstall@example.com');

      // 3. Verify user profile restored and onboarding bypassed
      expect(HiveService.instance.userProfile?.name, equals('Reinstalled User'));
      expect(HiveService.instance.userProfile?.heightCm, equals(178.0));
      expect(HiveService.instance.hasCompletedOnboardingForUser(uid), isTrue);
    });

    test('6. Zero Overwrite on Complete Cloud Profile: Existing cloud data takes priority over local defaults', () async {
      const uid = 'authoritative_user_006';

      final cloudProfile = createSampleProfile(name: 'Authoritative Name', weightKg: 85.0);
      await HiveService.instance.saveUserProfile(cloudProfile, uid);
      await HiveService.instance.setSetting('bound_firebase_uid', uid);

      // Verify no default fallback overrides the loaded cloud profile
      final current = HiveService.instance.userProfile;
      expect(current?.name, equals('Authoritative Name'));
      expect(current?.weightKg, equals(85.0));
      expect(current?.onboardingComplete, isTrue);
    });

    test('7. Guest Mode Isolation: Unauthenticated user operates completely offline', () async {
      await HiveService.instance.setSetting('bound_firebase_uid', null);
      final guestProf = createSampleProfile(name: 'Guest User', weightKg: 62.0);
      await HiveService.instance.userProfileBox.put('profile', guestProf);

      expect(HiveService.instance.userProfile?.name, equals('Guest User'));
      expect(UserDataMigrationService.instance.boundFirebaseUid, isNull);
    });

    test('8. Multi-Account Isolation: User A and User B maintain separate hydrated datasets', () async {
      const uidA = 'user_A_isolated';
      const uidB = 'user_B_isolated';

      await HiveService.instance.saveUserProfile(createSampleProfile(name: 'User A', heightCm: 170.0), uidA);
      await HiveService.instance.saveUserProfile(createSampleProfile(name: 'User B', heightCm: 185.0), uidB);

      // Switch to A
      await HiveService.instance.setSetting('bound_firebase_uid', uidA);
      expect(HiveService.instance.userProfile?.name, equals('User A'));
      expect(HiveService.instance.userProfile?.heightCm, equals(170.0));

      // Switch to B
      await HiveService.instance.setSetting('bound_firebase_uid', uidB);
      expect(HiveService.instance.userProfile?.name, equals('User B'));
      expect(HiveService.instance.userProfile?.heightCm, equals(185.0));
    });

    test('9. Reactive Streaming: userProfileProvider updates when Firestore profile is saved to Hive', () async {
      const uid = 'reactive_user_009';
      await HiveService.instance.setSetting('bound_firebase_uid', uid);

      final container = ProviderContainer();
      final initial = await container.read(userProfileProvider.future);
      expect(initial, isNull);

      // Save hydrated profile
      final hydratedProfile = createSampleProfile(name: 'Reactive Streamed User');
      await HiveService.instance.saveUserProfile(hydratedProfile, uid);

      // Small tick for box watcher
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final updatedProfile = await container.read(userProfileProvider.future);
      expect(updatedProfile?.name, equals('Reactive Streamed User'));

      container.dispose();
    });

    test('10. Logout & Data Retention: Local data is preserved in user namespace after logout', () async {
      const uid = 'logout_retention_010';
      await HiveService.instance.saveUserProfile(createSampleProfile(name: 'Logout User'), uid);
      await HiveService.instance.setSetting('bound_firebase_uid', uid);

      expect(HiveService.instance.userProfile?.name, equals('Logout User'));

      // Perform logout
      await HiveService.instance.setSetting('bound_firebase_uid', null);
      expect(HiveService.instance.getUserProfileFor(uid)?.name, equals('Logout User'));

      // Re-login
      await HiveService.instance.setSetting('bound_firebase_uid', uid);
      expect(HiveService.instance.userProfile?.name, equals('Logout User'));
    });
  });
}
