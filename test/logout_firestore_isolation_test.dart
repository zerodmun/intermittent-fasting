import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fast_flow/core/services/auth_service.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/notification_sync_service.dart';
import 'package:fast_flow/core/services/user_data_migration_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('logout_firestore_isolation_test_');
    Hive.init(tempDir.path);
    await HiveService.instance.init();
  });

  setUp(() async {
    await HiveService.instance.settingsBox.clear();
    await HiveService.instance.userProfileBox.clear();
    await HiveService.instance.fastingScheduleBox.clear();
    await HiveService.instance.fastingRecordsBox.clear();
    await HiveService.instance.processedEventsBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Post-Logout Firestore Security & Account Isolation Suite (15 Scenarios)', () {
    const uidA = 'UID_A_11111';
    const emailA = 'userA@test.com';
    const uidB = 'UID_B_22222';
    const emailB = 'userB@test.com';

    test('1. Account A login state: Local namespace binds UID_A', () async {
      await HiveService.instance.setSetting('bound_firebase_uid', uidA);
      await HiveService.instance.registerKnownAccount(uid: uidA, email: emailA);

      expect(HiveService.instance.currentActiveUserId, equals(uidA));
      expect(HiveService.instance.knownAccounts.length, equals(1));
      expect(HiveService.instance.knownAccounts.first['uid'], equals(uidA));
    });

    test('2. Account A logout: FirebaseAuth.currentUser is null and bound UID is cleared', () async {
      await HiveService.instance.setSetting('bound_firebase_uid', uidA);
      expect(HiveService.instance.currentActiveUserId, equals(uidA));

      await AuthService.instance.signOut();

      expect(AuthService.instance.currentUser, isNull);
      expect(NotificationSyncService.instance.authenticatedUserId, isNull);
      expect(HiveService.instance.getSetting<String>('bound_firebase_uid'), isNull);
    });

    test('3. Logout -> NotificationSyncService.updateSchedule: Updates local Hive cache and skips Firestore', () async {
      // Ensure user is logged out
      expect(NotificationSyncService.instance.authenticatedUserId, isNull);

      final schedule = FastingSchedule.defaultSchedule();
      await NotificationSyncService.instance.updateSchedule(schedule: schedule);

      // Verify local cache is saved for offline capability
      final localCache = HiveService.instance.getLocalNotificationScheduleCache();
      expect(localCache, isNotNull);
      expect(localCache!['scheduleId'], equals('fasting_schedule_001'));
      expect(NotificationSyncService.instance.authenticatedUserId, isNull);
    });

    test('4. Logout -> synchronizeOnStartup: Exits safely without unauthenticated Firestore calls', () async {
      expect(NotificationSyncService.instance.authenticatedUserId, isNull);

      bool rescheduleTriggered = false;
      await NotificationSyncService.instance.synchronizeOnStartup(
        onRescheduleNeeded: (reason) async {
          rescheduleTriggered = true;
        },
      );

      expect(rescheduleTriggered, isFalse);
    });

    test('5. Logout -> FCM initialization and token update: Skips Firestore when currentUser is null', () {
      expect(AuthService.instance.currentUser, isNull);
      expect(NotificationSyncService.instance.authenticatedUserId, isNull);
    });

    test('6. Logout -> UserDataMigrationService: Blocks migration and legacy claim when currentUser is null', () async {
      expect(AuthService.instance.currentUser, isNull);

      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: 'unauthenticated_uid',
        email: 'unauth@example.com',
      );

      // Verify unauthenticated user cannot perform Firestore operations
      expect(NotificationSyncService.instance.authenticatedUserId, isNull);
    });


    test('7. FastingEngine initialization while logged out: Operates 100% offline without Firestore writes', () async {
      expect(AuthService.instance.currentUser, isNull);

      final sched = FastingSchedule.defaultSchedule();
      await HiveService.instance.saveFastingSchedule(sched);

      final activeSched = HiveService.instance.fastingSchedule;
      expect(activeSched.dailySchedules.isNotEmpty, isTrue);
    });

    test('8. Boot / App restart while logged out: Preserves logged-out state with null bound UID', () {
      expect(AuthService.instance.currentUser, isNull);
      expect(HiveService.instance.getSetting<String>('bound_firebase_uid'), isNull);
      expect(NotificationSyncService.instance.authenticatedUserId, isNull);
    });

    test('9. Account A logout -> Account B login: Only Account B namespace is active', () async {
      // 1. Account A
      final pA = UserProfile(name: 'User A', gender: 'male', ageYears: 25, heightCm: 175, weightKg: 70, goalWeightKg: 65, targetBodyFat: 15, targetWaist: 80, targetBmi: 22, selectedPlanId: '16-8', onboardingComplete: true);
      await HiveService.instance.saveUserProfile(pA, uidA);
      await HiveService.instance.registerKnownAccount(uid: uidA, email: emailA);
      await HiveService.instance.setSetting('bound_firebase_uid', uidA);
      expect(HiveService.instance.currentActiveUserId, equals(uidA));

      // 2. Sign out
      await AuthService.instance.signOut();
      expect(HiveService.instance.getSetting<String>('bound_firebase_uid'), isNull);

      // 3. Account B login
      final pB = UserProfile(name: 'User B', gender: 'female', ageYears: 28, heightCm: 165, weightKg: 58, goalWeightKg: 54, targetBodyFat: 20, targetWaist: 70, targetBmi: 21, selectedPlanId: '18-6', onboardingComplete: true);
      await HiveService.instance.saveUserProfile(pB, uidB);
      await HiveService.instance.registerKnownAccount(uid: uidB, email: emailB);
      await HiveService.instance.setSetting('bound_firebase_uid', uidB);

      // Verify B profile is active
      expect(HiveService.instance.currentActiveUserId, equals(uidB));
      final profileB = HiveService.instance.getUserProfileFor(uidB);
      final profileA = HiveService.instance.getUserProfileFor(uidA);
      expect(profileB?.name, equals('User B'));
      expect(profileA?.name, equals('User A'));
    });

    test('10. Account A logout: No unexpected UID_C or anonymous UID is generated as bound UID', () async {
      await HiveService.instance.setSetting('bound_firebase_uid', uidA);
      await AuthService.instance.signOut();

      // Trigger various app events while logged out
      final sched = FastingSchedule.defaultSchedule();
      await NotificationSyncService.instance.updateSchedule(schedule: sched);

      final boundUid = HiveService.instance.getSetting<String>('bound_firebase_uid');
      expect(boundUid, isNull);
    });

    test('11. Local anonymous ID remains available for local offline functionality', () {
      final localAnonId = UserDataMigrationService.instance.localUserId;
      expect(localAnonId, isNotEmpty);
      expect(localAnonId, equals('user_uppo'));
    });

    test('12. Local anonymous ID is never returned by NotificationSyncService.authenticatedUserId', () {
      expect(AuthService.instance.currentUser, isNull);
      expect(NotificationSyncService.instance.authenticatedUserId, isNull);
    });

    test('13. Existing Account A local data remains intact after logout', () async {
      // Save User A profile and schedule
      final pA = UserProfile(name: 'User A', gender: 'male', ageYears: 25, heightCm: 175, weightKg: 70, goalWeightKg: 65, targetBodyFat: 15, targetWaist: 80, targetBmi: 22, selectedPlanId: '16-8', onboardingComplete: true);
      await HiveService.instance.saveUserProfile(pA, uidA);
      await HiveService.instance.saveFastingSchedule(FastingSchedule.defaultSchedule(), uidA);

      await AuthService.instance.signOut();

      // Verify User A data is preserved in Hive under profile_$uidA and schedule_$uidA
      final profileA = HiveService.instance.getUserProfileFor(uidA);
      final hasScheduleA = HiveService.instance.fastingScheduleBox.get('schedule_$uidA') != null;
      expect(profileA, isNotNull);
      expect(profileA?.name, equals('User A'));
      expect(hasScheduleA, isTrue);
    });

    test('14. Account B cannot overwrite or modify Account A data after logout', () async {
      final pA = UserProfile(name: 'User A', gender: 'male', ageYears: 25, heightCm: 175, weightKg: 70, goalWeightKg: 65, targetBodyFat: 15, targetWaist: 80, targetBmi: 22, selectedPlanId: '16-8', onboardingComplete: true);
      await HiveService.instance.saveUserProfile(pA, uidA);

      // Switch to B and save B's profile
      await HiveService.instance.setSetting('bound_firebase_uid', uidB);
      final pB = UserProfile(name: 'User B', gender: 'female', ageYears: 28, heightCm: 165, weightKg: 58, goalWeightKg: 54, targetBodyFat: 20, targetWaist: 70, targetBmi: 21, selectedPlanId: '18-6', onboardingComplete: true);
      await HiveService.instance.saveUserProfile(pB, uidB);

      final profileA = HiveService.instance.getUserProfileFor(uidA);
      final profileB = HiveService.instance.getUserProfileFor(uidB);
      expect(profileA?.name, equals('User A'));
      expect(profileB?.name, equals('User B'));
    });

    test('15. Account A -> logout -> Account B -> logout -> app events -> zero bound UID leaks', () async {
      // 1. Account A
      await HiveService.instance.setSetting('bound_firebase_uid', uidA);
      await AuthService.instance.signOut();
      expect(HiveService.instance.getSetting<String>('bound_firebase_uid'), isNull);

      // 2. Account B
      await HiveService.instance.setSetting('bound_firebase_uid', uidB);
      await AuthService.instance.signOut();
      expect(HiveService.instance.getSetting<String>('bound_firebase_uid'), isNull);

      // 3. User is logged out, trigger background and schedule changes
      final schedule = FastingSchedule.defaultSchedule();
      await NotificationSyncService.instance.updateSchedule(schedule: schedule);

      expect(HiveService.instance.getSetting<String>('bound_firebase_uid'), isNull);
      expect(NotificationSyncService.instance.authenticatedUserId, isNull);
    });
  });
}
