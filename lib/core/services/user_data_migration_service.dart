import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/logger_service.dart';
import 'package:fast_flow/core/services/notification_service.dart';
import 'package:fast_flow/core/services/notification_sync_service.dart';
import 'package:fast_flow/features/fasting/data/services/fasting_engine.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';

class AccountSwitchConflictException implements Exception {
  final String message;
  AccountSwitchConflictException([
    this.message = 'A different account was previously bound to this device. Local data has been preserved safely without overwriting.',
  ]);
  @override
  String toString() => message;
}

class UserDataMigrationService {
  UserDataMigrationService._();
  static final UserDataMigrationService instance = UserDataMigrationService._();

  FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  bool _migrationInProgress = false;

  @visibleForTesting
  void setMockFirestore(FirebaseFirestore firestore) {
    _customFirestore = firestore;
  }

  /// Gets current migration status: 'legacy_local_user', 'migration_pending', 'completed'
  String get migrationStatus {
    return HiveService.instance.getSetting<String>('migration_status') ?? 'legacy_local_user';
  }

  /// Gets bound Firebase UID linked to this local installation
  String? get boundFirebaseUid {
    return HiveService.instance.getSetting<String>('bound_firebase_uid');
  }

  /// Gets original local anonymous user ID (preserved across updates)
  String get localUserId {
    var anonId = HiveService.instance.getSetting<String>('anon_user_id') ??
        HiveService.instance.getSetting<String>('legacy_user_id');
    if (anonId == null || anonId.isEmpty) {
      anonId = 'user_uppo';
      HiveService.instance.setSetting('anon_user_id', anonId);
    }
    return anonId;
  }

  /// Explicitly claims and migrates local legacy user data for a Firebase user
  Future<void> claimLocalDataForFirebaseUser(String newUid, {String? email}) async {
    await processPostLoginMigration(uid: newUid, email: email ?? '');
  }

  /// Safe, non-destructive migration handler run after successful Firebase Auth sign-in or sign-up
  Future<void> processPostLoginMigration({
    required String uid,
    required String email,
  }) async {
    // 1. Migration lock to prevent concurrent executions
    if (_migrationInProgress) {
      LoggerService.i('UserDataMigrationService: Migration already in progress for UID: $uid');
      return;
    }

    final currentClaimedUid = HiveService.instance.getSetting<String>('claimed_by_uid') ??
        HiveService.instance.getSetting<String>('first_bound_uid');
    final currentStatus = HiveService.instance.getSetting<String>('migration_status');

    // 2. Idempotency Check: Return early if this UID is already fully migrated
    if (currentStatus == 'completed' && currentClaimedUid == uid) {
      LoggerService.i('[LEGACY-RECOVERY] Migration already completed for UID: $uid');
      return;
    }

    _migrationInProgress = true;
    final deviceId = FcmService.instance.getOrCreateDeviceId();
    final legacyUserId = HiveService.instance.getSetting<String>('legacy_user_id') ??
        HiveService.instance.getSetting<String>('anon_user_id') ??
        'user_uppo';

    final hasLocalData = HiveService.instance.hasUnclaimedLocalUserData() ||
        HiveService.instance.getUserProfileFor(uid) != null;

    int recordsMigrated = 0;
    int recordsMerged = 0;

    // 3. Register known account
    await HiveService.instance.registerKnownAccount(uid: uid, email: email);

    // 4. Mark migration pending for crash safety
    await HiveService.instance.setSetting('migration_status', 'migration_pending');
    await HiveService.instance.setSetting('bound_firebase_uid', uid);

    try {
      // 5. Claim unclaimed legacy local data if this is the FIRST account on a device with local data
      if (HiveService.instance.hasUnclaimedLocalUserData()) {
        await HiveService.instance.claimLocalUserDataFor(uid);
      }

      // 6. Check if Firestore user doc exists
      final userDocRef = _firestore.collection('users').doc(uid);
      final userSnap = await userDocRef.get();

      final profile = HiveService.instance.getUserProfileFor(uid);


      if (!userSnap.exists) {
        // CASE A / C: Fresh Firestore user document creation (LOCAL -> CLOUD migration)
        final userData = <String, dynamic>{
          'uid': uid,
          'email': email,
          'deviceId': deviceId,
          'localUserId': legacyUserId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'accountStatus': 'active',
          'migrationStatus': 'completed',
        };

        if (profile != null) {
          userData['profile'] = {
            'name': profile.name,
            'gender': profile.gender,
            'ageYears': profile.ageYears,
            'heightCm': profile.heightCm,
            'weightKg': profile.weightKg,
            'goalWeightKg': profile.goalWeightKg,
            'targetBodyFat': profile.targetBodyFat,
            'targetWaist': profile.targetWaist,
            'targetBmi': profile.targetBmi,
            'selectedPlanId': profile.selectedPlanId,
            'onboardingComplete': true,
          };
        }

        await userDocRef.set(userData, SetOptions(merge: true));

        // Sync existing local fasting records to Firestore
        final records = HiveService.instance.allFastingRecords;
        for (final record in records) {
          final recordDoc = userDocRef.collection('fastingRecords').doc(record.id);
          await recordDoc.set({
            'id': record.id,
            'planName': record.planName,
            'fastingMinutes': record.fastingMinutes,
            'eatingMinutes': record.eatingMinutes,
            'startTime': Timestamp.fromDate(record.startTime),
            'endTime': record.endTime != null ? Timestamp.fromDate(record.endTime!) : null,
            'status': record.status,
            'note': record.note,
            'reason': record.reason,
            'createdAt': Timestamp.fromDate(record.createdAt),
            'updatedAt': Timestamp.fromDate(record.updatedAt),
          }, SetOptions(merge: true));
          recordsMigrated++;
        }
      } else {
        // CASE B: User document already exists in Firestore -> deterministic merge
        final data = userSnap.data();
        if (data != null && data.containsKey('profile')) {
          if (profile == null) {
            final pMap = Map<String, dynamic>.from(data['profile'] as Map);
            final cloudProfile = UserProfile(
              name: pMap['name']?.toString() ?? '',
              gender: pMap['gender']?.toString() ?? 'male',
              ageYears: (pMap['ageYears'] as num?)?.toInt() ?? 25,
              heightCm: (pMap['heightCm'] as num?)?.toDouble() ?? 170.0,
              weightKg: (pMap['weightKg'] as num?)?.toDouble() ?? 70.0,
              goalWeightKg: (pMap['goalWeightKg'] as num?)?.toDouble() ?? 65.0,
              targetBodyFat: (pMap['targetBodyFat'] as num?)?.toDouble() ?? 15.0,
              targetWaist: (pMap['targetWaist'] as num?)?.toDouble() ?? 80.0,
              targetBmi: (pMap['targetBmi'] as num?)?.toDouble() ?? 22.0,
              selectedPlanId: pMap['selectedPlanId']?.toString() ?? '16-8',
              onboardingComplete: true,
            );
            await HiveService.instance.saveUserProfile(cloudProfile, uid);
          }
        } else if (profile != null) {
          await userDocRef.set({
            'profile': {
              'name': profile.name,
              'gender': profile.gender,
              'ageYears': profile.ageYears,
              'heightCm': profile.heightCm,
              'weightKg': profile.weightKg,
              'goalWeightKg': profile.goalWeightKg,
              'targetBodyFat': profile.targetBodyFat,
              'targetWaist': profile.targetWaist,
              'targetBmi': profile.targetBmi,
              'selectedPlanId': profile.selectedPlanId,
              'onboardingComplete': true,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        // Merge local records with remote collection safely
        final records = HiveService.instance.allFastingRecords;
        for (final record in records) {
          final recordDoc = userDocRef.collection('fastingRecords').doc(record.id);
          final existingSnap = await recordDoc.get();
          if (!existingSnap.exists) {
            await recordDoc.set({
              'id': record.id,
              'planName': record.planName,
              'fastingMinutes': record.fastingMinutes,
              'eatingMinutes': record.eatingMinutes,
              'startTime': Timestamp.fromDate(record.startTime),
              'endTime': record.endTime != null ? Timestamp.fromDate(record.endTime!) : null,
              'status': record.status,
              'note': record.note,
              'reason': record.reason,
              'createdAt': Timestamp.fromDate(record.createdAt),
              'updatedAt': Timestamp.fromDate(record.updatedAt),
            }, SetOptions(merge: true));
            recordsMigrated++;
          } else {
            recordsMerged++;
          }
        }
      }

      // 7. Check if remote notification schedule exists
      final scheduleDocRef = userDocRef.collection('notificationSchedules').doc('fasting_schedule_001');
      final scheduleSnap = await scheduleDocRef.get();

      if (!scheduleSnap.exists) {
        final schedule = HiveService.instance.fastingSchedule;
        await NotificationSyncService.instance.updateSchedule(
          schedule: schedule,
          incrementVersion: false,
        );
      }

      // 8. Store migration markers
      await HiveService.instance.setSetting('legacy_user_id', legacyUserId);
      await HiveService.instance.setSetting('claimed_by_uid', uid);
      await HiveService.instance.setSetting('first_bound_uid', uid);
      await HiveService.instance.setSetting('legacy_data_claimed', true);
      await HiveService.instance.setSetting('migration_status', 'completed');

      final bool localProfileExists = HiveService.instance.userProfileBox.get('profile') != null ||
          HiveService.instance.userProfileBox.get('profile_$uid') != null;
      final bool localScheduleExists = HiveService.instance.fastingScheduleBox.get('schedule') != null ||
          HiveService.instance.fastingScheduleBox.get('schedule_$uid') != null;
      final int localFastingRecords = HiveService.instance.fastingRecordsBox.length;
      final int localWeightEntries = HiveService.instance.weightEntriesBox.length;
      final int localFoodLogs = HiveService.instance.foodLogsBox.length;
      final int localWorkoutLogs = HiveService.instance.workoutLogsBox.length;
      final bool cloudProfileExists = userSnap.exists && (userSnap.data()?.containsKey('profile') ?? false);
      final bool migrationPerformed = recordsMigrated > 0 || hasLocalData;
      final bool onboardingRequired = !HiveService.instance.hasCompletedOnboardingForUser(uid);

      LoggerService.i(
        '[LEGACY-RECOVERY]\n\n'
        'legacyUserId: $legacyUserId\n'
        'firebaseUid: $uid\n\n'
        'localProfileExists: $localProfileExists\n'
        'localScheduleExists: $localScheduleExists\n'
        'localFastingRecords: $localFastingRecords\n'
        'localWeightEntries: $localWeightEntries\n'
        'localFoodLogs: $localFoodLogs\n'
        'localWorkoutLogs: $localWorkoutLogs\n\n'
        'cloudProfileExists: $cloudProfileExists\n'
        'cloudFastingRecords: $recordsMerged\n\n'
        'migrationAlreadyCompleted: ${currentStatus == 'completed'}\n'
        'migrationPerformed: $migrationPerformed\n\n'
        'claimedByUid: $uid\n'
        'migrationStatus: completed\n\n'
        'finalActiveUid: $uid\n'
        'onboardingRequired: $onboardingRequired',
      );
    } catch (e) {
      LoggerService.e('UserDataMigrationService: Migration warning for UID $uid: $e');
      await HiveService.instance.setSetting('migration_status', 'completed');
    } finally {
      _migrationInProgress = false;
    }
  }

  /// Safely switches active account to targetUid
  Future<void> switchAccount(String targetUid) async {
    await HiveService.instance.setSetting('bound_firebase_uid', targetUid);
    await HiveService.instance.setSetting('migration_status', 'completed');

    // Notify FastingEngine of schedule/account switch
    try {
      FastingEngine().onScheduleChanged();
      NotificationService.instance.scheduleFastingNotifications();
      NotificationService.instance.scheduleReminderNotifications('Account Switch');
    } catch (_) {}

    // Re-register FCM device for the switched UID
    if (Firebase.apps.isNotEmpty) {
      try {
        await FcmService.instance.reRegisterToken();
      } catch (e) {
        LoggerService.w('UserDataMigrationService: FCM re-register warning during account switch: $e');
      }
    }
  }
}
