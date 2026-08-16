import 'dart:convert';
import 'dart:io';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fast_flow/core/services/logger_service.dart';

import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';
import 'package:fast_flow/features/weight/domain/entities/weight_entry.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fast_flow/core/services/notification_sync_service.dart';
import 'package:fast_flow/core/services/fcm_service.dart';



/// Centralized Hive database service
class HiveService {
  HiveService._();
  static final HiveService instance = HiveService._();

  // Box names
  static const String _userProfileBox = 'user_profile';
  static const String _fastingScheduleBox = 'fasting_schedule';
  static const String _fastingRecordsBox = 'fasting_records';
  static const String _weightEntriesBox = 'weight_entries';
  static const String _settingsBox = 'settings';
  static const String _activeSessionBox = 'active_session';
  static const String _foodLogsBox = 'food_logs';
  static const String _foodSearchCacheBox = 'food_search_cache';
  static const String _workoutLogsBox = 'workout_logs';
  static const String _notificationScheduleCacheBox = 'notification_schedule_cache';
  static const String _processedEventsBox = 'processed_events';

  late Box<UserProfile> userProfileBox;
  late Box<FastingSchedule> fastingScheduleBox;
  late Box<FastingRecord> fastingRecordsBox;
  late Box<WeightEntry> weightEntriesBox;
  late Box settingsBox;
  late Box activeSessionBox;
  late Box foodLogsBox;
  late Box foodSearchCacheBox;
  late Box workoutLogsBox;
  late Box notificationScheduleCacheBox;
  late Box processedEventsBox;

  /// Initialize Hive and open all boxes safely
  Future<void> init() async {
    try {
      await Hive.initFlutter();
    } catch (e) {
      LoggerService.e('HiveService: initFlutter failed', e);
    }

    // Register adapters safely to avoid duplicate registration errors
    _registerAdapterSafe(UserProfileAdapter());
    _registerAdapterSafe(FastingScheduleAdapter());
    _registerAdapterSafe(DailyScheduleAdapter());
    _registerAdapterSafe(FastingRecordAdapter());
    _registerAdapterSafe(WeightEntryAdapter());

    // Open all boxes concurrently to optimize startup time
    final opened = await Future.wait([
      _openBoxWithRecoveryAndFallback<UserProfile>(_userProfileBox),
      _openBoxWithRecoveryAndFallback<FastingSchedule>(_fastingScheduleBox),
      _openBoxWithRecoveryAndFallback<FastingRecord>(_fastingRecordsBox),
      _openBoxWithRecoveryAndFallback<WeightEntry>(_weightEntriesBox),
      _openBoxWithRecoveryAndFallback(_settingsBox),
      _openBoxWithRecoveryAndFallback(_activeSessionBox),
      _openBoxWithRecoveryAndFallback(_foodLogsBox),
      _openBoxWithRecoveryAndFallback(_foodSearchCacheBox),
      _openBoxWithRecoveryAndFallback(_workoutLogsBox),
      _openBoxWithRecoveryAndFallback(_notificationScheduleCacheBox),
      _openBoxWithRecoveryAndFallback(_processedEventsBox),
    ]);

    userProfileBox = opened[0] as Box<UserProfile>;
    fastingScheduleBox = opened[1] as Box<FastingSchedule>;
    fastingRecordsBox = opened[2] as Box<FastingRecord>;
    weightEntriesBox = opened[3] as Box<WeightEntry>;
    settingsBox = opened[4];
    activeSessionBox = opened[5];
    foodLogsBox = opened[6];
    foodSearchCacheBox = opened[7];
    workoutLogsBox = opened[8];
    notificationScheduleCacheBox = opened[9];
    processedEventsBox = opened[10];
  }

  void _registerAdapterSafe<T>(TypeAdapter<T> adapter) {
    try {
      if (!Hive.isAdapterRegistered(adapter.typeId)) {
        Hive.registerAdapter(adapter);
      }
    } catch (e) {
      LoggerService.e('HiveService: Failed to register adapter ${adapter.runtimeType}', e);
    }
  }

  Future<Box<T>> _openBoxWithRecoveryAndFallback<T>(String name) async {
    try {
      return await Hive.openBox<T>(name);
    } catch (e) {
      LoggerService.w('HiveService: Error opening box "$name": $e. Attempting recovery via deletion...');
      try {
        await Hive.deleteBoxFromDisk(name);
        return await Hive.openBox<T>(name);
      } catch (deletionError) {
        LoggerService.e('HiveService: Deletion recovery failed for box "$name"', deletionError);
        try {
          final tempDir = await getTemporaryDirectory();
          return await Hive.openBox<T>('${name}_temp', path: tempDir.path);
        } catch (tempDirError) {
          LoggerService.e('HiveService: Temp path recovery failed for box "$name"', tempDirError);
          try {
            final tempDir = await getTemporaryDirectory();
            final uniqueName = '${name}_fallback_${DateTime.now().millisecondsSinceEpoch}';
            return await Hive.openBox<T>(uniqueName, path: tempDir.path);
          } catch (fallbackError) {
            LoggerService.e('HiveService: Critical failure. Fallback box failed for "$name"', fallbackError);
            rethrow;
          }
        }
      }
    }
  }

  // ── Account Scoping Helpers ──

  String get localUserId => FcmService.instance.getOrCreateDeviceId();

  /// Returns current active user ID (Firebase Auth UID, bound UID, or local anonymous ID)

  String get currentActiveUserId {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.uid.isNotEmpty) {
        return user.uid;
      }
    } catch (_) {}
    return getSetting<String>('bound_firebase_uid') ?? localUserId;
  }

  // ── Unclaimed Legacy Data Migration Helpers ──

  /// Checks whether there is valid local user data (profile, history, weight, etc.)
  /// that has NOT yet been claimed by any Firebase account.
  bool hasUnclaimedLocalUserData() {
    final legacyDataClaimed = getSetting<bool>('legacy_data_claimed') ?? false;
    final firstBoundUid = getSetting<String>('first_bound_uid');
    final claimedByUid = getSetting<String>('claimed_by_uid');

    if (legacyDataClaimed || firstBoundUid != null || claimedByUid != null) {
      return false;
    }

    final legacyProf = userProfileBox.get('profile');
    final hasProfile = legacyProf != null && legacyProf.onboardingComplete;
    final hasRecords = fastingRecordsBox.values.any((r) => !r.id.contains('user_') && !r.id.contains('uid_'));
    final hasWeight = weightEntriesBox.values.any((w) => !w.id.contains('user_') && !w.id.contains('uid_'));

    return hasProfile || hasRecords || hasWeight;
  }

  /// Claims existing unclaimed local data for the specified Firebase UID
  Future<void> claimLocalUserDataFor(String uid) async {
    final legacyProf = userProfileBox.get('profile');
    if (legacyProf != null) {
      final claimedProf = legacyProf.copyWith();
      claimedProf.onboardingComplete = true;
      await userProfileBox.put('profile_$uid', claimedProf);
    }

    final legacySched = fastingScheduleBox.get('schedule');
    if (legacySched != null) {
      await fastingScheduleBox.put('schedule_$uid', legacySched.copyWith());
    }

    final legacyUserId = getSetting<String>('anon_user_id') ??
        getSetting<String>('legacy_user_id') ??
        'user_uppo';
    await setSetting('legacy_user_id', legacyUserId);
    await setSetting('claimed_by_uid', uid);
    await setSetting('first_bound_uid', uid);
    await setSetting('legacy_data_claimed', true);
    await setSetting('legacy_data_owner_uid', uid);
  }


  // ── Known Accounts Registry ──

  List<Map<String, String>> get knownAccounts {
    final raw = getSetting<List>('known_accounts');
    if (raw == null) return [];
    return raw.map((e) => Map<String, String>.from(e as Map)).toList();
  }

  Future<void> registerKnownAccount({required String uid, required String email, String? displayName}) async {
    final list = knownAccounts;
    final index = list.indexWhere((acc) => acc['uid'] == uid);
    final item = {
      'uid': uid,
      'email': email,
      'displayName': displayName ?? email.split('@').first,
    };
    if (index >= 0) {
      list[index] = item;
    } else {
      list.add(item);
    }
    await setSetting('known_accounts', list);
  }


  // ── User Profile ──

  UserProfile? getUserProfileFor([String? uid]) {
    final targetUid = uid ?? currentActiveUserId;
    try {
      // 1. Try UID-scoped profile key
      final userProf = userProfileBox.get('profile_$targetUid');
      if (userProf != null) return userProf;

      // 2. Fallback check for first bound UID or local user
      final firstBoundUid = getSetting<String>('first_bound_uid');
      if (firstBoundUid == null || firstBoundUid == targetUid || targetUid == localUserId) {
        final legacyProf = userProfileBox.get('profile');
        if (legacyProf != null) {
          final cloned = legacyProf.copyWith();
          userProfileBox.put('profile_$targetUid', cloned);
          if (firstBoundUid == null && targetUid != localUserId) {
            setSetting('first_bound_uid', targetUid);
            setSetting('legacy_data_claimed', true);
            setSetting('legacy_data_owner_uid', targetUid);
          }
          return cloned;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  UserProfile? get userProfile => getUserProfileFor();

  /// Checks whether the specified user (or current active user) has completed onboarding.
  /// Returns true if:
  /// 1. User has an existing profile with onboardingComplete == true, OR
  /// 2. Current user has no profile yet, but there is unclaimed local data on this device
  ///    (which will be claimed during local-to-cloud migration).
  bool hasCompletedOnboardingForUser([String? uid]) {
    final targetUid = uid ?? currentActiveUserId;

    // 1. Check if targetUid already has its own profile
    final prof = getUserProfileFor(targetUid);
    if (prof != null && prof.onboardingComplete) {
      return true;
    }

    // 2. If targetUid has no profile yet, but unclaimed legacy local data exists,
    // this first account will claim the local data -> skip onboarding!
    if (hasUnclaimedLocalUserData()) {
      return true;
    }

    return false;
  }


  Future<void> saveUserProfile(UserProfile profile, [String? targetUid]) async {
    final uid = targetUid ?? currentActiveUserId;
    await userProfileBox.put('profile_$uid', profile);

    final firstBoundUid = getSetting<String>('first_bound_uid');
    if (firstBoundUid == null && uid != localUserId) {
      await setSetting('first_bound_uid', uid);
    }

    // Save to legacy fallback key using a SEPARATE CLONED INSTANCE to prevent HiveObject key collision
    if (uid == localUserId || uid == firstBoundUid) {
      await userProfileBox.put('profile', profile.copyWith());
    }

    if (Firebase.apps.isNotEmpty) {
      try {
        final currentSched = fastingSchedule;
        await NotificationSyncService.instance.updateSchedule(
          schedule: currentSched,
          incrementVersion: true,
        );
        await FcmService.instance.reRegisterToken();
      } catch (e) {
        LoggerService.w('HiveService: Error re-syncing identity after saving profile: $e');
      }
    }
  }


  // ── Fasting Schedule ──

  FastingSchedule get fastingSchedule {
    try {
      final uid = currentActiveUserId;
      final sched = fastingScheduleBox.get('schedule_$uid');
      if (sched != null) return sched;

      final firstBoundUid = getSetting<String>('first_bound_uid');
      if (firstBoundUid == null || firstBoundUid == uid || uid == localUserId) {
        final legacySched = fastingScheduleBox.get('schedule');
        if (legacySched != null) {
          final cloned = legacySched.copyWith();
          fastingScheduleBox.put('schedule_$uid', cloned);
          return cloned;
        }
      }
    } catch (_) {}
    return FastingSchedule.defaultSchedule();
  }

  Future<void> saveFastingSchedule(FastingSchedule schedule, [String? targetUid]) async {
    final uid = targetUid ?? currentActiveUserId;
    await fastingScheduleBox.put('schedule_$uid', schedule);

    final firstBoundUid = getSetting<String>('first_bound_uid');
    // Save to legacy fallback key using a SEPARATE CLONED INSTANCE to prevent HiveObject key collision
    if (uid == localUserId || uid == firstBoundUid) {
      await fastingScheduleBox.put('schedule', schedule.copyWith());
    }
  }

  // ── Notification Cache & Event History ──

  Map<String, dynamic>? getLocalNotificationScheduleCache() {
    final data = notificationScheduleCacheBox.get('current_schedule');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> saveLocalNotificationScheduleCache(Map<String, dynamic> cache) async {
    await notificationScheduleCacheBox.put('current_schedule', cache);
  }

  /// Canonical event helper to match any backend/frontend event key format
  static String normalizeEventTypeForEventId(String eventIdOrType) {
    final lower = eventIdOrType.toLowerCase();
    if (lower.contains('start_reminder') || lower.contains('start_soon') || lower.contains('reminder_start')) {
      return 'FASTING_START_SOON';
    }
    if (lower.contains('end_reminder') || lower.contains('end_soon') || lower.contains('reminder_end') || lower.contains('iftar_soon')) {
      return 'FASTING_END_SOON';
    }
    if (lower.contains('fasting_start') || lower.contains('start_fast')) {
      return 'FASTING_START';
    }
    if (lower.contains('fasting_end') || lower.contains('eating_start') || lower.contains('iftar_time') || lower.contains('end_fast')) {
      return 'FASTING_END';
    }
    return eventIdOrType.toUpperCase();
  }

  static String extractEventDateStr(dynamic input) {
    if (input is DateTime) {
      return '${input.year.toString().padLeft(4, '0')}-${input.month.toString().padLeft(2, '0')}-${input.day.toString().padLeft(2, '0')}';
    }
    final str = input.toString();
    final dateMatch = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(str);
    if (dateMatch != null) {
      return dateMatch.group(1)!;
    }
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Set<String> generateAllEventAliases({
    required String eventIdOrType,
    dynamic scheduledDate,
    String? scheduleId,
    int? version,
  }) {
    final schedId = scheduleId ?? 'fasting_schedule_001';
    final normalizedType = normalizeEventTypeForEventId(eventIdOrType);
    final dateStr = extractEventDateStr(scheduledDate ?? eventIdOrType);
    final lowerType = normalizedType.toLowerCase();

    final aliases = <String>{};
    // 1. Direct input
    aliases.add(eventIdOrType);

    // 2. Canonical key
    aliases.add('canonical_${normalizedType}_$dateStr');

    // 3. Cloudflare Worker formats
    aliases.add('${schedId}_${lowerType}_$dateStr');
    if (version != null) {
      aliases.add('${schedId}_v${version}_${lowerType}_$dateStr');
    }
    for (int v = 1; v <= 10; v++) {
      aliases.add('${schedId}_v${v}_${lowerType}_$dateStr');
    }

    // 4. Cloud Functions format
    aliases.add('${schedId}_$lowerType');
    if (version != null) {
      aliases.add('${schedId}_v${version}_$lowerType');
    }
    for (int v = 1; v <= 10; v++) {
      aliases.add('${schedId}_v${v}_$lowerType');
    }

    // 5. ISO DateTime local format
    if (scheduledDate is DateTime) {
      aliases.add('${schedId}_${scheduledDate.toIso8601String()}_$normalizedType');
    }

    return aliases;
  }

  bool isEventProcessed(String eventId) {
    if (processedEventsBox.containsKey(eventId)) return true;
    final normalized = normalizeEventTypeForEventId(eventId);
    final dateStr = extractEventDateStr(eventId);
    final canonicalKey = 'canonical_${normalized}_$dateStr';
    if (processedEventsBox.containsKey(canonicalKey)) return true;

    final record = getDeliveryRecord(eventId);
    if (record != null) {
      final status = record['status']?.toString();
      return status == 'DELIVERED_LOCAL' ||
          status == 'DELIVERED_FCM' ||
          status == 'COMPLETED' ||
          status == 'FCM_SKIPPED_LOCAL_PRIMARY';
    }
    return false;
  }

  Future<void> markEventProcessed(String eventId) async {
    final aliases = generateAllEventAliases(eventIdOrType: eventId);
    final nowIso = DateTime.now().toIso8601String();
    for (final alias in aliases) {
      await processedEventsBox.put(alias, nowIso);
    }
    await pruneProcessedEvents();
  }

  bool isEventScheduledLocally(String eventKey) {
    return notificationScheduleCacheBox.containsKey('sched_$eventKey');
  }

  Future<void> markEventScheduledLocally(String eventKey, DateTime scheduledTime) async {
    await notificationScheduleCacheBox.put('sched_$eventKey', scheduledTime.toIso8601String());
  }

  Future<void> removeLocalScheduledEvent(String eventKey) async {
    await notificationScheduleCacheBox.delete('sched_$eventKey');
  }

  Future<void> clearLocalScheduledEvents() async {
    final keys = notificationScheduleCacheBox.keys.where((k) => k.toString().startsWith('sched_')).toList();
    for (final key in keys) {
      await notificationScheduleCacheBox.delete(key);
    }
  }

  Map<String, dynamic>? getDeliveryRecord(String eventId) {
    // 1. Direct lookup
    final raw = processedEventsBox.get('record_$eventId');
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    // 2. Canonical key lookup
    final normalized = normalizeEventTypeForEventId(eventId);
    final dateStr = extractEventDateStr(eventId);
    final canonicalKey = 'canonical_${normalized}_$dateStr';
    final canonicalRaw = processedEventsBox.get('record_$canonicalKey');
    if (canonicalRaw is Map) {
      return Map<String, dynamic>.from(canonicalRaw);
    }

    // 3. Scan existing records for matching eventType + date
    for (final key in processedEventsBox.keys) {
      if (key.toString().startsWith('record_')) {
        final rec = processedEventsBox.get(key);
        if (rec is Map) {
          final recType = rec['eventType']?.toString();
          final recSched = rec['scheduledAt']?.toString();
          if (recType != null && normalizeEventTypeForEventId(recType) == normalized) {
            if (recSched != null && extractEventDateStr(recSched) == dateStr) {
              return Map<String, dynamic>.from(rec);
            }
          }
        }
      }
    }

    return null;
  }

  Future<void> saveDeliveryRecord({
    required String eventId,
    required Map<String, dynamic> data,
  }) async {
    final dynamic scheduledDate = data['scheduledAt'] != null ? DateTime.tryParse(data['scheduledAt'].toString()) : null;
    final aliases = generateAllEventAliases(
      eventIdOrType: eventId,
      scheduledDate: scheduledDate,
      version: data['scheduleVersion'] as int?,
    );

    for (final alias in aliases) {
      await processedEventsBox.put('record_$alias', data);
      await processedEventsBox.put(alias, data['status'] ?? 'COMPLETED');
    }
  }

  /// Atomically claims delivery for an event to eliminate race conditions between isolates / async paths.
  /// Returns true if the claim was granted to the caller, or false if already claimed/delivered.
  Future<bool> tryClaimNotificationDelivery({
    required String eventId,
    required String source,
    String? eventType,
    DateTime? scheduledDate,
  }) async {
    final record = getDeliveryRecord(eventId);
    if (record != null) {
      final status = record['status']?.toString();
      if (status == 'DELIVERED_LOCAL' ||
          status == 'DELIVERED_FCM' ||
          status == 'COMPLETED' ||
          status == 'FCM_SKIPPED_LOCAL_PRIMARY') {
        return false;
      }
      if (source == 'FCM' && status == 'SCHEDULED_LOCAL') {
        final schedStr = record['scheduledAt']?.toString();
        if (schedStr != null) {
          final schedTime = DateTime.tryParse(schedStr);
          if (schedTime != null) {
            final now = DateTime.now();
            if (now.difference(schedTime).inMinutes.abs() <= 120) {
              await saveDeliveryRecord(eventId: eventId, data: {
                ...record,
                'status': 'FCM_SKIPPED_LOCAL_PRIMARY',
                'updatedAt': DateTime.now().toIso8601String(),
              });
              return false;
            }
          }
        }
      }
    }

    final normalized = normalizeEventTypeForEventId(eventType ?? eventId);
    final now = DateTime.now();
    await saveDeliveryRecord(eventId: eventId, data: {
      'eventId': eventId,
      'eventType': normalized,
      'source': source,
      'status': source == 'LOCAL_ALARM' ? 'DELIVERED_LOCAL' : 'DELIVERED_FCM',
      'scheduledAt': (scheduledDate ?? now).toIso8601String(),
      'claimedAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });
    return true;
  }



  Future<void> pruneProcessedEvents() async {
    if (processedEventsBox.length <= 100) return;
    final now = DateTime.now();
    final keysToRemove = <dynamic>[];
    for (final key in processedEventsBox.keys) {
      final val = processedEventsBox.get(key);
      if (val is String) {
        final date = DateTime.tryParse(val);
        if (date != null && now.difference(date).inDays > 7) {
          keysToRemove.add(key);
        }
      }
    }
    for (final key in keysToRemove) {
      await processedEventsBox.delete(key);
    }
  }

  // ── Fasting Records ──

  List<FastingRecord> get allFastingRecords {
    final uid = currentActiveUserId;
    final firstBoundUid = getSetting<String>('first_bound_uid');

    final all = fastingRecordsBox.values.toList();
    return all.where((record) {
      if (record.id.contains(uid)) return true;
      if (!record.id.contains('user_') && !record.id.contains('uid_')) {
        return firstBoundUid == null || firstBoundUid == uid || uid == localUserId;
      }
      return false;
    }).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  Future<void> saveFastingRecord(FastingRecord record) async {
    await fastingRecordsBox.put(record.id, record);
  }

  Future<void> deleteFastingRecord(String id) async {
    final deleted = settingsBox.get('deleted_sessions') as List?;
    final updated = deleted != null ? List<String>.from(deleted.map((e) => e.toString())) : <String>[];
    if (!updated.contains(id)) {
      updated.add(id);
      await settingsBox.put('deleted_sessions', updated);
    }
    await fastingRecordsBox.delete(id);
  }

  // ── Weight Entries ──

  List<WeightEntry> get allWeightEntries {
    final uid = currentActiveUserId;
    final firstBoundUid = getSetting<String>('first_bound_uid');

    final all = weightEntriesBox.values.toList();
    return all.where((entry) {
      if (entry.id.contains(uid)) return true;
      if (!entry.id.contains('user_') && !entry.id.contains('uid_')) {
        return firstBoundUid == null || firstBoundUid == uid || uid == localUserId;
      }
      return false;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }


  Future<void> saveWeightEntry(WeightEntry entry) async {
    await weightEntriesBox.put(entry.id, entry);
  }

  Future<void> deleteWeightEntry(String id) async {
    await weightEntriesBox.delete(id);
  }

  // ── Active Session ──

  Map<String, dynamic>? get activeSession {
    final data = activeSessionBox.get('session');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> saveActiveSession(Map<String, dynamic> session) async {
    await activeSessionBox.put('session', session);
  }

  Future<void> clearActiveSession() async {
    await activeSessionBox.delete('session');
  }

  // ── Settings ──

  T? getSetting<T>(String key) {
    try {
      return settingsBox.get(key) as T?;
    } catch (_) {
      return null;
    }
  }

  Future<void> setSetting(String key, dynamic value) async {
    try {
      await settingsBox.put(key, value);
    } catch (_) {}
  }

  // ── Export / Import ──

  Future<String> exportData() async {
    final data = {
      'version': 1,
      'exportDate': DateTime.now().toIso8601String(),
      'userProfile': userProfile != null
          ? {
              'name': userProfile!.name,
              'gender': userProfile!.gender,
              'ageYears': userProfile!.ageYears,
              'heightCm': userProfile!.heightCm,
              'weightKg': userProfile!.weightKg,
              'goalWeightKg': userProfile!.goalWeightKg,
              'targetBodyFat': userProfile!.targetBodyFat,
              'targetWaist': userProfile!.targetWaist,
              'targetBmi': userProfile!.targetBmi,
              'selectedPlanId': userProfile!.selectedPlanId,
            }
          : null,
      'fastingSchedule': {
        'dailySchedules': fastingSchedule.dailySchedules.map(
          (key, value) => MapEntry(key.toString(), value.toJson()),
        ),
      },
      'fastingRecords': allFastingRecords
          .map((r) => {
                'id': r.id,
                'planName': r.planName,
                'fastingMinutes': r.fastingMinutes,
                'eatingMinutes': r.eatingMinutes,
                'startTime': r.startTime.toIso8601String(),
                'endTime': r.endTime?.toIso8601String(),
                'status': r.status,
                'note': r.note,
                'reason': r.reason,
              })
          .toList(),
      'weightEntries': allWeightEntries
          .map((w) => {
                'id': w.id,
                'weightKg': w.weightKg,
                'date': w.date.toIso8601String(),
                'bodyFatPercentage': w.bodyFatPercentage,
                'leanMassKg': w.leanMassKg,
                'fatMassKg': w.fatMassKg,
                'bmi': w.bmi,
                'bmr': w.bmr,
                'tdee': w.tdee,
                'waistCm': w.waistCm,
                'neckCm': w.neckCm,
                'hipCm': w.hipCm,
                'chestCm': w.chestCm,
                'leftArmCm': w.leftArmCm,
                'rightArmCm': w.rightArmCm,
                'leftForearmCm': w.leftForearmCm,
                'rightForearmCm': w.rightForearmCm,
                'leftThighCm': w.leftThighCm,
                'rightThighCm': w.rightThighCm,
                'leftCalfCm': w.leftCalfCm,
                'rightCalfCm': w.rightCalfCm,
                'shoulderCm': w.shoulderCm,
                'note': w.note,
              })
          .toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/fastflow_export.json');
    await file.writeAsString(jsonString);
    return file.path;
  }

  Future<void> importData(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    // Import user profile
    if (data['userProfile'] != null) {
      final p = data['userProfile'] as Map<String, dynamic>;
      await saveUserProfile(UserProfile(
        name: p['name'] as String,
        gender: p['gender'] as String,
        ageYears: p['ageYears'] as int,
        heightCm: (p['heightCm'] as num).toDouble(),
        weightKg: (p['weightKg'] as num).toDouble(),
        goalWeightKg: (p['goalWeightKg'] as num).toDouble(),
        targetBodyFat: (p['targetBodyFat'] as num).toDouble(),
        targetWaist: (p['targetWaist'] as num).toDouble(),
        targetBmi: (p['targetBmi'] as num).toDouble(),
        selectedPlanId: p['selectedPlanId'] as String,
        onboardingComplete: true,
      ));
    }

    // Import fasting schedule
    if (data['fastingSchedule'] != null) {
      final schedData = data['fastingSchedule'] as Map<String, dynamic>;
      final dailySchedules = <int, DailySchedule>{};
      (schedData['dailySchedules'] as Map<String, dynamic>).forEach((key, value) {
        final v = value as Map<String, dynamic>;
        dailySchedules[int.parse(key)] = DailySchedule(
          fastHour: v['fastHour'] as int,
          fastMin: v['fastMin'] as int,
          eatHour: v['eatHour'] as int,
          eatMin: v['eatMin'] as int,
        );
      });
      await saveFastingSchedule(FastingSchedule(dailySchedules: dailySchedules));
    }

    // Import fasting records
    final records = data['fastingRecords'] as List<dynamic>?;
    if (records != null) {
      for (final r in records) {
        final map = r as Map<String, dynamic>;
        await saveFastingRecord(FastingRecord(
          id: map['id'] as String,
          planName: map['planName'] as String,
          fastingMinutes: map['fastingMinutes'] as int,
          eatingMinutes: map['eatingMinutes'] as int,
          startTime: DateTime.parse(map['startTime'] as String),
          endTime: map['endTime'] != null ? DateTime.parse(map['endTime'] as String) : null,
          status: map['status'] as String,
          note: map['note'] as String?,
          reason: map['reason'] as String?,
        ));
      }
    }

    // Import weight entries
    final weights = data['weightEntries'] as List<dynamic>?;
    if (weights != null) {
      for (final w in weights) {
        final map = w as Map<String, dynamic>;
        await saveWeightEntry(WeightEntry(
          id: map['id'] as String,
          weightKg: (map['weightKg'] as num).toDouble(),
          date: DateTime.parse(map['date'] as String),
          bodyFatPercentage: (map['bodyFatPercentage'] as num?)?.toDouble(),
          leanMassKg: (map['leanMassKg'] as num?)?.toDouble(),
          fatMassKg: (map['fatMassKg'] as num?)?.toDouble(),
          bmi: (map['bmi'] as num?)?.toDouble(),
          bmr: (map['bmr'] as num?)?.toDouble(),
          tdee: (map['tdee'] as num?)?.toDouble(),
          waistCm: (map['waistCm'] as num?)?.toDouble(),
          neckCm: (map['neckCm'] as num?)?.toDouble(),
          hipCm: (map['hipCm'] as num?)?.toDouble(),
          chestCm: (map['chestCm'] as num?)?.toDouble(),
          leftArmCm: (map['leftArmCm'] as num?)?.toDouble(),
          rightArmCm: (map['rightArmCm'] as num?)?.toDouble(),
          leftForearmCm: (map['leftForearmCm'] as num?)?.toDouble(),
          rightForearmCm: (map['rightForearmCm'] as num?)?.toDouble(),
          leftThighCm: (map['leftThighCm'] as num?)?.toDouble(),
          rightThighCm: (map['rightThighCm'] as num?)?.toDouble(),
          leftCalfCm: (map['leftCalfCm'] as num?)?.toDouble(),
          rightCalfCm: (map['rightCalfCm'] as num?)?.toDouble(),
          shoulderCm: (map['shoulderCm'] as num?)?.toDouble(),
          note: map['note'] as String?,
        ));
      }
    }
  }

  // ── Food Logs ──

  List<Map<String, dynamic>> get allFoodLogs {
    try {
      return foodLogsBox.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      LoggerService.e('HiveService: Error reading food logs', e);
      return [];
    }
  }

  Future<void> saveFoodLog(String id, Map<String, dynamic> entry) async {
    await foodLogsBox.put(id, entry);
  }

  Future<void> deleteFoodLog(String id) async {
    await foodLogsBox.delete(id);
  }

  // ── Workout Logs ──

  List<Map<String, dynamic>> get allWorkoutLogs {
    try {
      return workoutLogsBox.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      LoggerService.e('HiveService: Error reading workout logs', e);
      return [];
    }
  }

  Future<void> saveWorkoutLog(String id, Map<String, dynamic> entry) async {
    await workoutLogsBox.put(id, entry);
  }

  Future<void> deleteWorkoutLog(String id) async {
    await workoutLogsBox.delete(id);
  }

  /// Clear all data
  Future<void> resetAll() async {
    await userProfileBox.clear();
    await fastingScheduleBox.clear();
    await fastingRecordsBox.clear();
    await weightEntriesBox.clear();
    await settingsBox.clear();
    await activeSessionBox.clear();
    await foodLogsBox.clear();
    await foodSearchCacheBox.clear();
    await workoutLogsBox.clear();
  }
}