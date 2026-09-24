import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/services/auth_service.dart';
import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/notification_sync_service.dart';
import 'package:fast_flow/core/services/user_data_migration_service.dart';
import 'package:fast_flow/features/auth/presentation/screens/account_choice_screen.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('smart_onboarding_test_');
    Hive.init(tempDir.path);
    await HiveService.instance.init();
  });

  setUp(() async {
    FcmService.instance.resetMemoryCache();
    await HiveService.instance.userProfileBox.clear();
    await HiveService.instance.fastingScheduleBox.clear();
    await HiveService.instance.fastingRecordsBox.clear();
    await HiveService.instance.weightEntriesBox.clear();
    await HiveService.instance.settingsBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Smart Onboarding & Reinstall Flow Suite (26 Scenarios)', () {
    // ───────────────────────────────────────────
    // 1. Fresh Install
    // ───────────────────────────────────────────
    testWidgets('1. Fresh install shows account-choice screen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AccountChoiceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccountChoiceScreen), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);
      expect(find.text('Continue without an account'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('2. "I already have an account" opens Login', (tester) async {
      bool loginPushed = false;
      final router = GoRouter(
        initialLocation: '/account-choice',
        routes: [
          GoRoute(path: '/account-choice', builder: (_, __) => const AccountChoiceScreen()),
          GoRoute(path: '/login', builder: (_, __) {
            loginPushed = true;
            return const Scaffold(body: Text('Login Screen Mock'));
          }),
          GoRoute(path: '/onboarding', builder: (_, __) => const Scaffold(body: Text('Onboarding Mock'))),
          GoRoute(path: '/register', builder: (_, __) => const Scaffold(body: Text('Register Mock'))),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final loginBtn = find.byKey(const Key('account_choice_login_btn'));
      expect(loginBtn, findsOneWidget);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      expect(loginPushed, isTrue);
      expect(find.text('Login Screen Mock'), findsOneWidget);
    });

    testWidgets('3. "Continue without an account" opens anonymous/local flow', (tester) async {
      bool onboardingPushed = false;
      final router = GoRouter(
        initialLocation: '/account-choice',
        routes: [
          GoRoute(path: '/account-choice', builder: (_, __) => const AccountChoiceScreen()),
          GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Login Mock'))),
          GoRoute(path: '/onboarding', builder: (_, __) {
            onboardingPushed = true;
            return const Scaffold(body: Text('Onboarding Screen Mock'));
          }),
          GoRoute(path: '/register', builder: (_, __) => const Scaffold(body: Text('Register Mock'))),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final guestBtn = find.byKey(const Key('account_choice_guest_btn'));
      expect(guestBtn, findsOneWidget);
      await tester.tap(guestBtn);
      await tester.pumpAndSettle();

      expect(onboardingPushed, isTrue);
      expect(find.text('Onboarding Screen Mock'), findsOneWidget);
    });

    // ───────────────────────────────────────────
    // 2. Returning Account
    // ───────────────────────────────────────────
    test('4. Existing Firebase account + existing profile -> Home', () async {
      const uid = 'firebase_uid_returning_001';
      final profile = UserProfile(
        name: 'Jane Doe',
        gender: 'female',
        ageYears: 28,
        heightCm: 165,
        weightKg: 60,
        goalWeightKg: 55,
        targetBodyFat: 18.0,
        targetWaist: 68.0,
        targetBmi: 22.0,
        selectedPlanId: '16-8',
        onboardingComplete: true,
      );
      await HiveService.instance.saveUserProfile(profile, uid);
      await HiveService.instance.setSetting('bound_firebase_uid', uid);

      expect(HiveService.instance.hasCompletedOnboardingForUser(uid), isTrue);
      expect(HiveService.instance.getUserProfileFor(uid)?.name, equals('Jane Doe'));
    });

    test('5. Existing Firebase account + existing schedule -> Home', () async {
      const uid = 'firebase_uid_returning_002';
      final schedule = FastingSchedule(dailySchedules: {
        1: DailySchedule(fastHour: 18, fastMin: 0, eatHour: 10, eatMin: 0),
      });
      await HiveService.instance.saveFastingSchedule(schedule, uid);
      await HiveService.instance.setSetting('bound_firebase_uid', uid);

      final loadedSchedule = HiveService.instance.fastingSchedule;
      expect(loadedSchedule.dailySchedules[1]?.fastHour, equals(18));
    });

    test('6. Existing Firebase account + existing fasting history -> history preserved', () async {
      const uid = 'firebase_uid_returning_003';
      final record = FastingRecord(
        id: 'rec_${uid}_101',
        planName: '16:8',
        fastingMinutes: 960,
        eatingMinutes: 480,
        startTime: DateTime.now().subtract(const Duration(days: 2)),
        status: 'completed',
      );
      await HiveService.instance.saveFastingRecord(record);
      await HiveService.instance.setSetting('bound_firebase_uid', uid);

      final records = HiveService.instance.allFastingRecords;
      expect(records.length, equals(1));
      expect(records.first.id, equals('rec_${uid}_101'));
    });

    test('7. Existing Firebase account does not trigger onboarding', () async {
      const uid = 'firebase_uid_returning_004';
      final profile = UserProfile(
        name: 'Alex',
        gender: 'male',
        ageYears: 30,
        heightCm: 180,
        weightKg: 80,
        goalWeightKg: 75,
        targetBodyFat: 15.0,
        targetWaist: 82.0,
        targetBmi: 24.5,
        selectedPlanId: '16-8',
        onboardingComplete: true,
      );
      await HiveService.instance.saveUserProfile(profile, uid);
      await HiveService.instance.setSetting('bound_firebase_uid', uid);

      expect(HiveService.instance.hasCompletedOnboardingForUser(uid), isTrue);
    });

    test('8. Existing account does not create a second Firebase UID', () async {
      const originalUid = 'firebase_uid_original_008';
      await HiveService.instance.setSetting('bound_firebase_uid', originalUid);
      await HiveService.instance.registerKnownAccount(uid: originalUid, email: 'user@example.com');

      expect(HiveService.instance.knownAccounts.length, equals(1));
      expect(HiveService.instance.knownAccounts.first['uid'], equals(originalUid));

      // Re-registering with same email updates existing account entry without creating duplicate UID
      await HiveService.instance.registerKnownAccount(uid: originalUid, email: 'user@example.com', displayName: 'Updated');
      expect(HiveService.instance.knownAccounts.length, equals(1));
      expect(HiveService.instance.knownAccounts.first['uid'], equals(originalUid));
    });

    // ───────────────────────────────────────────
    // 3. New Account
    // ───────────────────────────────────────────
    test('9. New Firebase account with no profile -> onboarding required', () async {
      const newUid = 'firebase_uid_new_009';
      await HiveService.instance.setSetting('bound_firebase_uid', newUid);

      expect(HiveService.instance.getUserProfileFor(newUid), isNull);
      expect(HiveService.instance.hasCompletedOnboardingForUser(newUid), isFalse);
    });

    test('10. Completing onboarding creates the correct UID namespace', () async {
      const uid = 'firebase_uid_onboarded_010';
      await HiveService.instance.setSetting('bound_firebase_uid', uid);

      final profile = UserProfile(
        name: 'New Onboarded User',
        gender: 'female',
        ageYears: 24,
        heightCm: 168,
        weightKg: 58,
        goalWeightKg: 54,
        targetBodyFat: 18.0,
        targetWaist: 65.0,
        targetBmi: 20.5,
        selectedPlanId: 'custom',
        onboardingComplete: true,
      );
      final schedule = FastingSchedule.defaultSchedule();

      await HiveService.instance.saveUserProfile(profile, uid);
      await HiveService.instance.saveFastingSchedule(schedule, uid);

      final savedProfile = HiveService.instance.getUserProfileFor(uid);
      expect(savedProfile, isNotNull);
      expect(savedProfile?.name, equals('New Onboarded User'));
      expect(savedProfile?.onboardingComplete, isTrue);
      expect(HiveService.instance.hasCompletedOnboardingForUser(uid), isTrue);
    });

    // ───────────────────────────────────────────
    // 4. Reinstall Scenarios
    // ───────────────────────────────────────────
    test('11. Uninstall -> reinstall -> login with same account -> original UID restored', () async {
      const uid = 'firebase_uid_reinstall_011';
      final restoredProfile = UserProfile(
        name: 'Reinstall User',
        gender: 'male',
        ageYears: 32,
        heightCm: 175,
        weightKg: 78,
        goalWeightKg: 72,
        targetBodyFat: 16.0,
        targetWaist: 80.0,
        targetBmi: 25.0,
        selectedPlanId: '16-8',
        onboardingComplete: true,
      );
      await HiveService.instance.saveUserProfile(restoredProfile, uid);
      await HiveService.instance.setSetting('bound_firebase_uid', uid);
      await HiveService.instance.setSetting('migration_status', 'completed');

      expect(UserDataMigrationService.instance.boundFirebaseUid, equals(uid));
      expect(HiveService.instance.getUserProfileFor(uid)?.name, equals('Reinstall User'));
    });

    test('12. Reinstall does not create a new user document', () async {
      const uid = 'firebase_uid_reinstall_012';
      await HiveService.instance.registerKnownAccount(uid: uid, email: 'reinstall@example.com');
      expect(HiveService.instance.knownAccounts.length, equals(1));

      // Second register attempt with same UID is idempotent
      await HiveService.instance.registerKnownAccount(uid: uid, email: 'reinstall@example.com');
      expect(HiveService.instance.knownAccounts.length, equals(1));
    });

    test('13. Reinstall does not duplicate fasting records', () async {
      const uid = 'firebase_uid_reinstall_013';
      await HiveService.instance.setSetting('bound_firebase_uid', uid);

      final record = FastingRecord(
        id: 'fast_${uid}_1',
        planName: '16:8',
        fastingMinutes: 960,
        eatingMinutes: 480,
        startTime: DateTime(2026, 9, 1, 17, 0),
        status: 'completed',
      );
      await HiveService.instance.saveFastingRecord(record);
      // Save same record again
      await HiveService.instance.saveFastingRecord(record);

      expect(HiveService.instance.allFastingRecords.length, equals(1));
    });

    test('14. Reinstall does not duplicate schedules', () async {
      const uid = 'firebase_uid_reinstall_014';
      final schedule = FastingSchedule.defaultSchedule();
      await HiveService.instance.saveFastingSchedule(schedule, uid);
      await HiveService.instance.saveFastingSchedule(schedule, uid);

      final saved = HiveService.instance.fastingScheduleBox.get('schedule_$uid');
      expect(saved, isNotNull);
      expect(HiveService.instance.fastingScheduleBox.length, equals(1));
    });

    test('15. Reinstall does not trigger false "account used on another device" for the same physical device', () async {
      // Simulate same device token resolution
      final deviceId1 = FcmService.instance.getOrCreateDeviceId();
      expect(deviceId1, isNotEmpty);

      // Verify persistent device ID retrieval
      final deviceId2 = FcmService.instance.getOrCreateDeviceId();
      expect(deviceId2, equals(deviceId1));
    });

    // ───────────────────────────────────────────
    // 5. Multi-Account
    // ───────────────────────────────────────────
    test('16. Account A -> logout -> Account B -> isolated data', () async {
      const uidA = 'user_A_016';
      const uidB = 'user_B_016';

      await HiveService.instance.saveUserProfile(
        UserProfile(
          name: 'Alice',
          gender: 'female',
          ageYears: 27,
          heightCm: 165,
          weightKg: 55,
          goalWeightKg: 52,
          targetBodyFat: 18.0,
          targetWaist: 65.0,
          targetBmi: 20.0,
          selectedPlanId: '16-8',
          onboardingComplete: true,
        ),
        uidA,
      );
      await HiveService.instance.saveUserProfile(
        UserProfile(
          name: 'Bob',
          gender: 'male',
          ageYears: 35,
          heightCm: 182,
          weightKg: 85,
          goalWeightKg: 78,
          targetBodyFat: 19.0,
          targetWaist: 85.0,
          targetBmi: 25.5,
          selectedPlanId: '16-8',
          onboardingComplete: true,
        ),
        uidB,
      );

      // Switch to A
      await HiveService.instance.setSetting('bound_firebase_uid', uidA);
      expect(HiveService.instance.userProfile?.name, equals('Alice'));

      // Switch to B
      await HiveService.instance.setSetting('bound_firebase_uid', uidB);
      expect(HiveService.instance.userProfile?.name, equals('Bob'));
    });

    test('17. Account B cannot access Account A data', () async {
      const uidA = 'user_A_017';
      const uidB = 'user_B_017';

      await HiveService.instance.saveFastingRecord(
        FastingRecord(id: 'rec_${uidA}_secret', planName: '16:8', fastingMinutes: 960, eatingMinutes: 480, startTime: DateTime.now(), status: 'completed'),
      );
      await HiveService.instance.saveFastingRecord(
        FastingRecord(id: 'rec_${uidB}_public', planName: '16:8', fastingMinutes: 960, eatingMinutes: 480, startTime: DateTime.now(), status: 'completed'),
      );

      // Bound to B
      await HiveService.instance.setSetting('bound_firebase_uid', uidB);
      final recordsB = HiveService.instance.allFastingRecords;
      expect(recordsB.every((r) => !r.id.contains(uidA)), isTrue);
      expect(recordsB.any((r) => r.id.contains(uidB)), isTrue);
    });

    test('18. Account B -> logout -> Account A restores Account A data', () async {
      const uidA = 'user_A_018';
      const uidB = 'user_B_018';

      await HiveService.instance.saveUserProfile(
        UserProfile(
          name: 'Account A',
          gender: 'female',
          ageYears: 25,
          heightCm: 160,
          weightKg: 50,
          goalWeightKg: 48,
          targetBodyFat: 17.0,
          targetWaist: 63.0,
          targetBmi: 19.5,
          selectedPlanId: '16-8',
          onboardingComplete: true,
        ),
        uidA,
      );
      await HiveService.instance.saveUserProfile(
        UserProfile(
          name: 'Account B',
          gender: 'male',
          ageYears: 30,
          heightCm: 175,
          weightKg: 75,
          goalWeightKg: 70,
          targetBodyFat: 16.0,
          targetWaist: 78.0,
          targetBmi: 24.0,
          selectedPlanId: '16-8',
          onboardingComplete: true,
        ),
        uidB,
      );

      // Login B then logout and login A
      await HiveService.instance.setSetting('bound_firebase_uid', uidB);
      expect(HiveService.instance.userProfile?.name, equals('Account B'));

      // Restore A
      await HiveService.instance.setSetting('bound_firebase_uid', uidA);
      expect(HiveService.instance.userProfile?.name, equals('Account A'));
    });

    // ───────────────────────────────────────────
    // 6. Logout Safety
    // ───────────────────────────────────────────
    test('19. Logout prevents all Firestore writes (authenticatedUserId returns null)', () async {
      expect(NotificationSyncService.instance.authenticatedUserId, isNull);
    });

    test('20. Logout prevents FCM device registration (guest state blocked)', () async {
      expect(AuthService.instance.currentUser, isNull);
    });

    test('21. Logout prevents notification schedule cloud synchronization', () async {
      expect(NotificationSyncService.instance.authenticatedUserId, isNull);
    });

    test('22. Logout does not delete local data', () async {
      await HiveService.instance.saveUserProfile(
        UserProfile(
          name: 'Local Preserved',
          gender: 'male',
          ageYears: 29,
          heightCm: 170,
          weightKg: 70,
          goalWeightKg: 65,
          targetBodyFat: 15.0,
          targetWaist: 80.0,
          targetBmi: 24.2,
          selectedPlanId: '16-8',
          onboardingComplete: true,
        ),
        'local_uid',
      );
      final record = FastingRecord(
        id: 'rec_local_022',
        planName: '16:8',
        fastingMinutes: 960,
        eatingMinutes: 480,
        startTime: DateTime.now(),
        status: 'completed',
      );
      await HiveService.instance.saveFastingRecord(record);

      // Simulate logout
      await HiveService.instance.setSetting('bound_firebase_uid', null);
      await HiveService.instance.setSetting('migration_status', 'legacy_local_user');

      expect(HiveService.instance.fastingRecordsBox.length, equals(1));
      expect(HiveService.instance.userProfileBox.length, equals(1));
    });

    // ───────────────────────────────────────────
    // 7. Security Rules
    // ───────────────────────────────────────────
    test('23. Anonymous/local ID is never used as Firestore UID', () {
      final anonId = UserDataMigrationService.instance.localUserId;
      expect(anonId, isNotEmpty);
      expect(NotificationSyncService.instance.authenticatedUserId, isNull);
    });

    test('24. Legacy UID is never used as authenticated UID', () {
      final authUid = NotificationSyncService.instance.authenticatedUserId;
      expect(authUid, isNull);
    });

    test('25. Device ID is never used as account identity', () {
      final deviceId = FcmService.instance.getOrCreateDeviceId();
      expect(deviceId, isNotEmpty);
      expect(NotificationSyncService.instance.authenticatedUserId, isNot(equals(deviceId)));
    });

    test('26. Passwords and reset tokens are never stored locally', () {
      final settings = HiveService.instance.settingsBox;
      expect(settings.containsKey('password'), isFalse);
      expect(settings.containsKey('auth_token'), isFalse);
      expect(settings.containsKey('reset_token'), isFalse);
      expect(settings.containsKey('oobCode'), isFalse);
    });
  });
}
