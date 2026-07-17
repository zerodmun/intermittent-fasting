import 'dart:convert';
import 'dart:io';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:fast_flow/features/fasting/models/fasting_record.dart';
import 'package:fast_flow/features/fasting/models/fasting_schedule.dart';
import 'package:fast_flow/features/onboarding/models/user_profile.dart';
import 'package:fast_flow/features/weight/models/weight_entry.dart';

/// Manages Hive database initialization and box access.
class HiveService {
  HiveService._();
  static final HiveService instance = HiveService._();

  static const String _userProfileBox = 'user_profile';
  static const String _fastingRecordsBox = 'fasting_records';
  static const String _weightEntriesBox = 'weight_entries';
  static const String _settingsBox = 'settings';
  static const String _activeSessionBox = 'active_session';
  static const String _fastingScheduleBox = 'fasting_schedule';

  late Box<UserProfile> userProfileBox;
  late Box<FastingRecord> fastingRecordsBox;
  late Box<WeightEntry> weightEntriesBox;
  late Box settingsBox;
  late Box activeSessionBox;
  late Box<FastingSchedule> fastingScheduleBox;

  /// Initialize Hive and open all boxes.
  Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(UserProfileAdapter());
    Hive.registerAdapter(FastingRecordAdapter());
    Hive.registerAdapter(WeightEntryAdapter());
    Hive.registerAdapter(FastingScheduleAdapter());

    // Open boxes
    userProfileBox = await Hive.openBox<UserProfile>(_userProfileBox);
    fastingRecordsBox = await Hive.openBox<FastingRecord>(_fastingRecordsBox);
    weightEntriesBox = await Hive.openBox<WeightEntry>(_weightEntriesBox);
    settingsBox = await Hive.openBox(_settingsBox);
    activeSessionBox = await Hive.openBox(_activeSessionBox);
    fastingScheduleBox = await Hive.openBox<FastingSchedule>(_fastingScheduleBox);
  }

  // ── User Profile ──

  UserProfile? get userProfile => userProfileBox.get('profile');

  Future<void> saveUserProfile(UserProfile profile) async {
    await userProfileBox.put('profile', profile);
  }

  // ── Fasting Schedule ──

  FastingSchedule get fastingSchedule {
    final sched = fastingScheduleBox.get('schedule');
    if (sched != null) return sched;
    return FastingSchedule.defaultSchedule();
  }

  Future<void> saveFastingSchedule(FastingSchedule schedule) async {
    await fastingScheduleBox.put('schedule', schedule);
  }

  // ── Fasting Records ──

  List<FastingRecord> get allFastingRecords =>
      fastingRecordsBox.values.toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

  Future<void> saveFastingRecord(FastingRecord record) async {
    await fastingRecordsBox.put(record.id, record);
  }

  Future<void> deleteFastingRecord(String id) async {
    await fastingRecordsBox.delete(id);
  }

  // ── Weight Entries ──

  List<WeightEntry> get allWeightEntries =>
      weightEntriesBox.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));

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

  T? getSetting<T>(String key) => settingsBox.get(key) as T?;

  Future<void> setSetting(String key, dynamic value) async {
    await settingsBox.put(key, value);
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
              'heightCm': userProfile!.heightCm,
              'weightKg': userProfile!.weightKg,
              'goalWeightKg': userProfile!.goalWeightKg,
              'selectedPlanId': userProfile!.selectedPlanId,
            }
          : null,
      'fastingRecords': allFastingRecords
          .map((r) => {
                'id': r.id,
                'planName': r.planName,
                'fastingMinutes': r.fastingMinutes,
                'eatingMinutes': r.eatingMinutes,
                'startTime': r.startTime.toIso8601String(),
                'endTime': r.endTime?.toIso8601String(),
                'status': r.status,
              })
          .toList(),
      'weightEntries': allWeightEntries
          .map((w) => {
                'id': w.id,
                'weightKg': w.weightKg,
                'date': w.date.toIso8601String(),
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
        heightCm: (p['heightCm'] as num).toDouble(),
        weightKg: (p['weightKg'] as num).toDouble(),
        goalWeightKg: (p['goalWeightKg'] as num).toDouble(),
        selectedPlanId: p['selectedPlanId'] as String,
        onboardingComplete: true,
      ));
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
          endTime: map['endTime'] != null
              ? DateTime.parse(map['endTime'] as String)
              : null,
          status: map['status'] as String,
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
          note: map['note'] as String?,
        ));
      }
    }
  }

  /// Clear all data.
  Future<void> resetAll() async {
    await userProfileBox.clear();
    await fastingRecordsBox.clear();
    await weightEntriesBox.clear();
    await settingsBox.clear();
    await activeSessionBox.clear();
  }
}
