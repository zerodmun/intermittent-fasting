import 'dart:convert';
import 'dart:io';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';
import 'package:fast_flow/features/weight/domain/entities/weight_entry.dart';

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

  late Box<UserProfile> userProfileBox;
  late Box<FastingSchedule> fastingScheduleBox;
  late Box<FastingRecord> fastingRecordsBox;
  late Box<WeightEntry> weightEntriesBox;
  late Box settingsBox;
  late Box activeSessionBox;

  /// Initialize Hive and open all boxes
  Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(UserProfileAdapter());
    Hive.registerAdapter(FastingScheduleAdapter());
    Hive.registerAdapter(DailyScheduleAdapter());
    Hive.registerAdapter(FastingRecordAdapter());
    Hive.registerAdapter(WeightEntryAdapter());

    // Open boxes
    userProfileBox = await Hive.openBox<UserProfile>(_userProfileBox);
    fastingScheduleBox = await Hive.openBox<FastingSchedule>(_fastingScheduleBox);
    fastingRecordsBox = await Hive.openBox<FastingRecord>(_fastingRecordsBox);
    weightEntriesBox = await Hive.openBox<WeightEntry>(_weightEntriesBox);
    settingsBox = await Hive.openBox(_settingsBox);
    activeSessionBox = await Hive.openBox(_activeSessionBox);
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

  /// Clear all data
  Future<void> resetAll() async {
    await userProfileBox.clear();
    await fastingScheduleBox.clear();
    await fastingRecordsBox.clear();
    await weightEntriesBox.clear();
    await settingsBox.clear();
    await activeSessionBox.clear();
  }
}