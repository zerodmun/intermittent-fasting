import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/logger_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';

/// Manages synchronization between local notification schedule cache
/// and the authoritative Firestore document at users/{userId}/notificationSchedules/{scheduleId}.
class NotificationSyncService {
  NotificationSyncService._();
  static final NotificationSyncService instance = NotificationSyncService._();

  static const String scheduleId = 'fasting_schedule_001';
  FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  String get userId {
    final profile = HiveService.instance.userProfile;
    if (profile != null && profile.name.trim().isNotEmpty) {
      return 'user_${profile.name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    }
    var anonId = HiveService.instance.getSetting<String>('anon_user_id');
    if (anonId == null || anonId.isEmpty) {
      anonId = 'user_anon_${DateTime.now().millisecondsSinceEpoch}';
      HiveService.instance.setSetting('anon_user_id', anonId);
    }
    return anonId;
  }

  /// Returns current schedule version from local cache (defaults to 1).
  int get localVersion {
    final cache = HiveService.instance.getLocalNotificationScheduleCache();
    if (cache != null && cache.containsKey('version')) {
      return (cache['version'] as num).toInt();
    }
    return 1;
  }

  /// Builds standardized notification schedule payload for Firestore and local cache.
  Map<String, dynamic> buildScheduleDocument({
    required FastingSchedule schedule,
    required int version,
  }) {
    final enabled = HiveService.instance.getSetting<bool>('notifications_enabled') ?? true;
    final startReminder = HiveService.instance.getSetting<bool>('reminder_fasting_enabled') ?? true;
    final startNotification = HiveService.instance.getSetting<bool>('fasting_notification_enabled') ?? true;
    final endReminder = HiveService.instance.getSetting<bool>('reminder_iftar_enabled') ?? true;
    final endNotification = HiveService.instance.getSetting<bool>('eating_notification_enabled') ?? true;
    final sound = HiveService.instance.getSetting<String>('reminder_sound') ?? 'app_notification';
    final vibration = HiveService.instance.getSetting<bool>('reminder_vibration') ?? true;

    final now = DateTime.now();
    final todaySchedule = schedule.getScheduleFor(now.weekday);

    final dailyMap = <String, dynamic>{};
    schedule.dailySchedules.forEach((key, val) {
      dailyMap[key.toString()] = {
        'fastHour': val.fastHour,
        'fastMin': val.fastMin,
        'eatHour': val.eatHour,
        'eatMin': val.eatMin,
      };
    });

    return {
      'scheduleId': scheduleId,
      'enabled': enabled,
      'startTime': todaySchedule.fastTimeFormatted,
      'endTime': todaySchedule.eatTimeFormatted,
      'reminderBeforeStart': 10,
      'reminderBeforeEnd': 10,
      'timezone': 'Asia/Jakarta',
      'version': version,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'notificationSettings': {
        'startReminder': startReminder,
        'startNotification': startNotification,
        'endReminder': endReminder,
        'endNotification': endNotification,
        'sound': sound,
        'alarmEnabled': vibration,
      },
      'dailySchedules': dailyMap,
    };
  }

  /// Pushes updated schedule to Firestore and updates local cache with incremented version.
  Future<void> updateSchedule({
    required FastingSchedule schedule,
    bool incrementVersion = true,
  }) async {
    final newVersion = incrementVersion ? localVersion + 1 : localVersion;
    final docData = buildScheduleDocument(schedule: schedule, version: newVersion);

    // Update local cache immediately
    await HiveService.instance.saveLocalNotificationScheduleCache(docData);

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notificationSchedules')
          .doc(scheduleId)
          .set(docData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));

      if (kDebugMode) {
        debugPrint('[NotificationSyncService] Schedule updated in Firestore: Version $newVersion');
      }
    } catch (e) {
      LoggerService.w('NotificationSyncService: Failed pushing schedule update to Firestore (saved locally): $e');
    }

    await _syncScheduleToCloudflare(schedule: schedule, version: newVersion);
  }

  Future<void> _syncScheduleToCloudflare({
    required FastingSchedule schedule,
    required int version,
  }) async {
    final enabled = HiveService.instance.getSetting<bool>('notifications_enabled') ?? true;
    final now = DateTime.now();
    final todaySchedule = schedule.getScheduleFor(now.weekday);

    final payload = {
      'scheduleId': scheduleId,
      'userId': userId,
      'enabled': enabled,
      'timezone': 'Asia/Jakarta',
      'fastHour': todaySchedule.fastHour,
      'fastMinute': todaySchedule.fastMin,
      'eatHour': todaySchedule.eatHour,
      'eatMinute': todaySchedule.eatMin,
      'reminderBeforeStart': 10,
      'reminderBeforeEnd': 10,
      'version': version,
    };

    try {
      final response = await http
          .post(
            Uri.parse('https://fomo-notification-scheduler.zerodmun2.workers.dev/schedule'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (kDebugMode) {
          debugPrint('[NotificationSyncService] Schedule synced to Cloudflare Worker successfully: Version $version');
        }
      } else {
        if (kDebugMode) {
          debugPrint('[NotificationSyncService] Cloudflare Worker schedule sync returned status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationSyncService] Cloudflare Worker schedule sync error: $e');
      }
    }
  }

  /// Compares local schedule version against Firestore remote schedule on app startup.
  /// Synchronizes local fallback schedule only if remote version is newer or local is missing.
  Future<void> synchronizeOnStartup({
    required Future<void> Function(String reason) onRescheduleNeeded,
  }) async {
    final localCache = HiveService.instance.getLocalNotificationScheduleCache();
    final localVer = localVersion;

    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('notificationSchedules')
          .doc(scheduleId);

      final snapshot = await docRef.get().timeout(const Duration(seconds: 5));

      if (!snapshot.exists || snapshot.data() == null) {
        // Initial upload if missing remotely
        final currentSched = HiveService.instance.fastingSchedule;
        await updateSchedule(schedule: currentSched, incrementVersion: false);
        return;
      }

      final remoteData = snapshot.data()!;
      final remoteVer = (remoteData['version'] as num?)?.toInt() ?? 1;

      if (localCache == null || remoteVer > localVer) {
        if (kDebugMode) {
          debugPrint('[NotificationSyncService] Sync: Remote version ($remoteVer) > Local version ($localVer). Updating local schedule...');
        }
        await HiveService.instance.saveLocalNotificationScheduleCache(remoteData);
        await onRescheduleNeeded('Startup Remote Sync Update (v$remoteVer)');
      } else if (remoteVer == localVer) {
        if (kDebugMode) {
          debugPrint('[NotificationSyncService] Sync: Versions match (v$localVer). Preserving existing local schedule without recreation.');
        }
      } else {
        // Local is newer than remote (e.g. edited offline), push to remote
        final currentSched = HiveService.instance.fastingSchedule;
        await updateSchedule(schedule: currentSched, incrementVersion: false);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationSyncService] Startup sync skipped or offline: $e');
      }
      // Offline fallback: keep existing local schedule intact
    }
  }
}
