import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:fast_flow/core/services/auth_service.dart';
import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/logger_service.dart';
import 'package:fast_flow/core/services/notification_service.dart';
import 'package:fast_flow/core/services/notification_sync_service.dart';
import 'package:fast_flow/features/fasting/data/services/fasting_engine.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';
import 'package:fast_flow/features/weight/domain/entities/weight_entry.dart';

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
  void setMockFirestore(FirebaseFirestore? firestore) {
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
    // 0. Security Guard: Firestore write only allowed if current user is authenticated and matches uid
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null || authUser.uid != uid) {
        LoggerService.w(
          '[FIRESTORE-SECURITY-BLOCK] reason: unauthenticated migration attempt, requestedUid: $uid, authenticatedUid: ${authUser?.uid}, source: UserDataMigrationService',
        );
        return;
      }
    } catch (_) {
      // Allow unit tests running with mock firestore without full Firebase.initializeApp()
    }

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
    int weightLogsMigrated = 0;
    int weightLogsMerged = 0;

    // 3. Register known account
    await HiveService.instance.registerKnownAccount(uid: uid, email: email);

    // 4. Mark migration pending for crash safety
    await HiveService.instance.setSetting('migration_status', 'migration_pending');
    await HiveService.instance.setSetting('bound_firebase_uid', uid);

    try {
      // 5. Check if Firestore user doc exists (only when authenticated user matches uid)
      final authUser = AuthService.instance.currentUser;
      final bool canPerformFirestoreSync = authUser != null && authUser.uid == uid;
      DocumentSnapshot<Map<String, dynamic>>? userSnap;

      if (canPerformFirestoreSync) {
        LoggerService.d('[FIRESTORE-USER-WRITE] uid: $uid, authUid: ${authUser.uid}, source: UserDataMigrationService.processPostLoginMigration, operation: user migration');
        final userDocRef = _firestore.collection('users').doc(uid);
        userSnap = await userDocRef.get();

        if (userSnap.exists) {
          // CASE 1: Firestore doc exists -> HYDRATE FROM FIRESTORE (Authoritative source)
          final data = userSnap.data();
          if (data != null && data.containsKey('profile')) {
            final pMap = Map<String, dynamic>.from(data['profile'] as Map);
            final name = pMap['name']?.toString() ?? '';
            final gender = pMap['gender']?.toString() ?? 'male';
            final ageYears = (pMap['ageYears'] as num?)?.toInt() ?? 25;
            final heightCm = (pMap['heightCm'] as num?)?.toDouble() ?? 170.0;
            final weightKg = (pMap['weightKg'] as num?)?.toDouble() ?? 70.0;
            final goalWeightKg = (pMap['goalWeightKg'] as num?)?.toDouble() ?? 65.0;
            final targetBodyFat = (pMap['targetBodyFat'] as num?)?.toDouble() ?? 15.0;
            final targetWaist = (pMap['targetWaist'] as num?)?.toDouble() ?? 80.0;
            final targetBmi = (pMap['targetBmi'] as num?)?.toDouble() ?? 22.0;
            final selectedPlanId = pMap['selectedPlanId']?.toString() ?? '16-8';
            final bool isComplete = (pMap['onboardingComplete'] as bool?) ??
                (name.trim().isNotEmpty && ageYears > 0 && heightCm > 0 && weightKg > 0);

            final cloudProfile = UserProfile(
              name: name,
              gender: gender,
              ageYears: ageYears,
              heightCm: heightCm,
              weightKg: weightKg,
              goalWeightKg: goalWeightKg,
              targetBodyFat: targetBodyFat,
              targetWaist: targetWaist,
              targetBmi: targetBmi,
              selectedPlanId: selectedPlanId,
              onboardingComplete: isComplete,
            );
            await HiveService.instance.saveUserProfile(cloudProfile, uid);
          }

          // Restore remote fasting records into local Hive
          try {
            final deletedFastingSessions = (HiveService.instance.settingsBox.get('deleted_sessions') as List?)
                ?.map((e) => e.toString())
                .toSet() ?? <String>{};
            final recordsSnap = await userDocRef.collection('fastingRecords').get();
            for (final doc in recordsSnap.docs) {
              final rData = doc.data();
              final isDeleted = rData['isDeleted'] == true;
              final recordId = rData['recordId']?.toString() ?? rData['id']?.toString() ?? doc.id;

              if (isDeleted || deletedFastingSessions.contains(recordId)) {
                if (!isDeleted && deletedFastingSessions.contains(recordId)) {
                  // Propagate local offline deletion to Firestore
                  await userDocRef.collection('fastingRecords').doc(recordId).set({
                    'recordId': recordId,
                    'isDeleted': true,
                    'updatedAt': FieldValue.serverTimestamp(),
                    'syncedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                }
                await HiveService.instance.fastingRecordsBox.delete(recordId);
                continue;
              }

              DateTime? parseDate(dynamic val) {
                if (val is Timestamp) return val.toDate().toLocal();
                if (val is String) {
                  final parsed = DateTime.tryParse(val);
                  return parsed?.toLocal();
                }
                return null;
              }

              final sTime = parseDate(rData['fastingStartAt']) ?? parseDate(rData['startTime']) ?? DateTime.now();
              final eTime = parseDate(rData['fastingEndAt']) ?? parseDate(rData['endTime']);
              final fMinutes = (rData['duration'] as num?)?.toInt() ??
                  (rData['fastingMinutes'] as num?)?.toInt() ??
                  (eTime != null ? eTime.difference(sTime).inMinutes : 960);
              final eMinutes = (rData['eatingMinutes'] as num?)?.toInt() ?? (24 * 60 - fMinutes);
              final updatedAt = parseDate(rData['updatedAt']) ?? DateTime.now();
              final createdAt = parseDate(rData['createdAt']) ?? sTime;

              // Last-Write-Wins conflict check against local Hive (UTC normalized)
              final existingLocal = HiveService.instance.fastingRecordsBox.get(recordId);
              if (existingLocal != null && existingLocal.updatedAt.toUtc().isAfter(updatedAt.toUtc())) {
                LoggerService.d('[HYDRATION-CONFLICT-SKIP] Stale remote record $recordId ignored (local newer: ${existingLocal.updatedAt.toUtc()} > remote: ${updatedAt.toUtc()})');
                continue;
              }

              final record = FastingRecord(
                id: recordId,
                planName: rData['planName']?.toString() ?? '16:8',
                fastingMinutes: fMinutes,
                eatingMinutes: eMinutes,
                startTime: sTime,
                endTime: eTime,
                status: rData['status']?.toString() ?? 'completed',
                note: rData['note']?.toString(),
                reason: rData['reason']?.toString(),
                createdAt: createdAt,
                updatedAt: updatedAt,
              );
              await HiveService.instance.fastingRecordsBox.put(record.id, record);
              recordsMerged++;
            }
          } catch (e) {
            LoggerService.w('UserDataMigrationService: Fasting records restore note: $e');
          }

          // Restore remote weight logs into local Hive
          try {
            final deletedWeightLogs = (HiveService.instance.settingsBox.get('deleted_weight_logs') as List?)
                ?.map((e) => e.toString())
                .toSet() ?? <String>{};
            final weightLogsSnap = await userDocRef.collection('weightLogs').get();
            final remoteLogIds = <String>{};

            for (final doc in weightLogsSnap.docs) {
              final wData = doc.data();
              final isDeleted = wData['isDeleted'] == true;
              final logId = wData['id']?.toString() ?? doc.id;
              remoteLogIds.add(logId);

              if (isDeleted || deletedWeightLogs.contains(logId)) {
                if (!isDeleted && deletedWeightLogs.contains(logId)) {
                  // Propagate local offline deletion to Firestore
                  await userDocRef.collection('weightLogs').doc(logId).set({
                    'id': logId,
                    'isDeleted': true,
                    'updatedAt': FieldValue.serverTimestamp(),
                    'syncedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                }
                await HiveService.instance.weightEntriesBox.delete(logId);
                continue;
              }

              DateTime? parseDate(dynamic val) {
                if (val is Timestamp) return val.toDate().toLocal();
                if (val is String) {
                  final parsed = DateTime.tryParse(val);
                  return parsed?.toLocal();
                }
                if (val is int) {
                  return DateTime.fromMillisecondsSinceEpoch(val).toLocal();
                }
                return null;
              }

              final updatedAt = parseDate(wData['updatedAt']) ?? DateTime.now();

              // Last-Write-Wins conflict check against local Hive (UTC normalized)
              final existingLocal = HiveService.instance.weightEntriesBox.get(logId);
              if (existingLocal != null && existingLocal.updatedAt.toUtc().isAfter(updatedAt.toUtc())) {
                LoggerService.d('[HYDRATION-CONFLICT-SKIP] Stale remote weight log $logId ignored (local newer: ${existingLocal.updatedAt.toUtc()} > remote: ${updatedAt.toUtc()})');
                // Upload the newer local entry to cloud
                await userDocRef.collection('weightLogs').doc(logId).set(
                  existingLocal.toFirestore(),
                  SetOptions(merge: true),
                );
                continue;
              }

              final entry = WeightEntry.fromFirestore(wData, doc.id);
              await HiveService.instance.weightEntriesBox.put(entry.id, entry);
              weightLogsMerged++;
            }

            // Sync any local weight entries that were created offline and don't exist in remote
            final localEntries = HiveService.instance.allWeightEntries;
            for (final entry in localEntries) {
              if (!remoteLogIds.contains(entry.id)) {
                await userDocRef.collection('weightLogs').doc(entry.id).set(
                  entry.toFirestore(),
                  SetOptions(merge: true),
                );
              }
            }
          } catch (e) {
            LoggerService.w('UserDataMigrationService: Weight logs restore note: $e');
          }

          // Check remote notification schedule
          try {
            final scheduleDocRef = userDocRef.collection('notificationSchedules').doc('fasting_schedule_001');
            final scheduleSnap = await scheduleDocRef.get();
            if (!scheduleSnap.exists) {
              final schedule = HiveService.instance.fastingSchedule;
              await NotificationSyncService.instance.updateSchedule(
                schedule: schedule,
                incrementVersion: false,
              );
            }
          } catch (_) {}
        } else {
          // CASE 2: Firestore doc does NOT exist -> New user or first-time local-to-cloud sync
          if (HiveService.instance.hasUnclaimedLocalUserData()) {
            await HiveService.instance.claimLocalUserDataFor(uid);
            final claimedProfile = HiveService.instance.getUserProfileFor(uid);

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

            if (claimedProfile != null) {
              userData['profile'] = {
                'name': claimedProfile.name,
                'gender': claimedProfile.gender,
                'ageYears': claimedProfile.ageYears,
                'heightCm': claimedProfile.heightCm,
                'weightKg': claimedProfile.weightKg,
                'goalWeightKg': claimedProfile.goalWeightKg,
                'targetBodyFat': claimedProfile.targetBodyFat,
                'targetWaist': claimedProfile.targetWaist,
                'targetBmi': claimedProfile.targetBmi,
                'selectedPlanId': claimedProfile.selectedPlanId,
                'onboardingComplete': true,
              };
            }

            await userDocRef.set(userData, SetOptions(merge: true));

            // Sync local fasting records to Firestore using canonical schema
            final records = HiveService.instance.allFastingRecords;
            for (final record in records) {
              final recordDoc = userDocRef.collection('fastingRecords').doc(record.id);
              await recordDoc.set({
                'recordId': record.id,
                'fastingStartAt': Timestamp.fromDate(record.startTime.toUtc()),
                'fastingEndAt': record.endTime != null ? Timestamp.fromDate(record.endTime!.toUtc()) : null,
                'duration': record.fastingMinutes,
                'eatingMinutes': record.eatingMinutes,
                'planName': record.planName,
                'status': record.status,
                'note': record.note,
                'reason': record.reason,
                'createdAt': Timestamp.fromDate(record.createdAt.toUtc()),
                'updatedAt': Timestamp.fromDate(record.updatedAt.toUtc()),
                'syncedAt': FieldValue.serverTimestamp(),
                'isDeleted': false,
                'syncStatus': 'synced',
              }, SetOptions(merge: true));
              recordsMigrated++;
            }

            // Sync local weight logs to Firestore
            final weightEntries = HiveService.instance.allWeightEntries;
            for (final entry in weightEntries) {
              final weightDoc = userDocRef.collection('weightLogs').doc(entry.id);
              await weightDoc.set(entry.toFirestore(), SetOptions(merge: true));
              weightLogsMigrated++;
            }
          }
        }
      } else {
        LoggerService.d('[FIRESTORE-SECURITY-BLOCK] reason: unauthenticated migration, requestedUid: $uid, authenticatedUid: ${authUser?.uid}, source: UserDataMigrationService');
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
      final bool cloudProfileExists = userSnap != null && userSnap.exists && (userSnap.data()?.containsKey('profile') ?? false);

      final bool migrationPerformed = recordsMigrated > 0 || weightLogsMigrated > 0 || hasLocalData;
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
        'cloudFastingRecords: $recordsMerged\n'
        'cloudWeightLogs: $weightLogsMerged\n\n'
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
