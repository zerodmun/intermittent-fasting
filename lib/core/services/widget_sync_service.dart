import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fast_flow/core/data/services/hive_service.dart';
import 'package:fast_flow/features/fasting/data/services/fasting_engine.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_state.dart';
import 'package:fast_flow/features/weight/domain/entities/body_comp_result.dart';
import 'package:fast_flow/features/weight/data/services/body_comp_calculator.dart';
import 'package:fast_flow/core/helpers/streak_calculator.dart';

class WidgetSettings {
  final bool widgetEnabled;
  final bool notificationEnabled;
  final bool liveCountdownEnabled;
  final bool progressRingEnabled;
  final bool bodyFatEnabled;
  final bool weightEnabled;

  const WidgetSettings({
    this.widgetEnabled = true,
    this.notificationEnabled = true,
    this.liveCountdownEnabled = true,
    this.progressRingEnabled = true,
    this.bodyFatEnabled = true,
    this.weightEnabled = true,
  });

  WidgetSettings copyWith({
    bool? widgetEnabled,
    bool? notificationEnabled,
    bool? liveCountdownEnabled,
    bool? progressRingEnabled,
    bool? bodyFatEnabled,
    bool? weightEnabled,
  }) {
    return WidgetSettings(
      widgetEnabled: widgetEnabled ?? this.widgetEnabled,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      liveCountdownEnabled: liveCountdownEnabled ?? this.liveCountdownEnabled,
      progressRingEnabled: progressRingEnabled ?? this.progressRingEnabled,
      bodyFatEnabled: bodyFatEnabled ?? this.bodyFatEnabled,
      weightEnabled: weightEnabled ?? this.weightEnabled,
    );
  }
}

class WidgetSyncService {
  static const _channel = MethodChannel('com.fastflow.app/widget_sync');

  WidgetSyncService._();

  static final WidgetSyncService instance = WidgetSyncService._internal();
  factory WidgetSyncService() => instance;
  WidgetSyncService._internal();

  WidgetSettings _settings = const WidgetSettings();
  WidgetSettings get settings => _settings;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _settings = WidgetSettings(
        widgetEnabled: prefs.getBool('widgetEnabled') ?? true,
        notificationEnabled: prefs.getBool('notificationEnabled') ?? true,
        liveCountdownEnabled: prefs.getBool('liveCountdownEnabled') ?? true,
        progressRingEnabled: prefs.getBool('progressRingEnabled') ?? true,
        bodyFatEnabled: prefs.getBool('bodyFatEnabled') ?? true,
        weightEnabled: prefs.getBool('weightEnabled') ?? true,
      );
      await syncToNative();
    } catch (e, stackTrace) {
      print('WidgetSyncService: Initialization failed: $e\n$stackTrace');
    }
  }

  Future<void> updateSettings(WidgetSettings newSettings) async {
    _settings = newSettings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('widgetEnabled', newSettings.widgetEnabled);
    await prefs.setBool('notificationEnabled', newSettings.notificationEnabled);
    await prefs.setBool('liveCountdownEnabled', newSettings.liveCountdownEnabled);
    await prefs.setBool('progressRingEnabled', newSettings.progressRingEnabled);
    await prefs.setBool('bodyFatEnabled', newSettings.bodyFatEnabled);
    await prefs.setBool('weightEnabled', newSettings.weightEnabled);
    await syncToNative();
  }

  Future<void> syncToNative() async {
    try {
      final state = FastingEngine().currentState;
      final profile = HiveService.instance.userProfile;
      final weightEntries = HiveService.instance.allWeightEntries;
      final fastingRecords = HiveService.instance.allFastingRecords;

      double? weight;
      double? bodyFat;
      if (weightEntries.isNotEmpty) {
        final latest = weightEntries.first;
        weight = latest.weightKg;
        if (profile != null) {
          final comp = BodyCompCalculator.calculate(
            profile: profile,
            weightKg: latest.weightKg,
            waistCm: latest.waistCm,
            neckCm: latest.neckCm,
            hipCm: latest.hipCm,
            gender: profile.gender,
          );
          bodyFat = comp?.bodyFatPercentage;
        }
      }

      final streakResult = StreakCalculator.calculate(fastingRecords);
      final streak = streakResult.currentStreak;

      String statusStr = 'COMPLETED';
      String phaseStr = 'eating';
      int startMs = 0;
      int endMs = 0;
      int nextTransitionMs = 0;

      if (state != null) {
        statusStr = state.status.name;
        phaseStr = state.currentPhase.name;
        startMs = state.activeWindowStart.millisecondsSinceEpoch;
        endMs = state.activeWindowEnd.millisecondsSinceEpoch;
        nextTransitionMs = state.nextTransition.millisecondsSinceEpoch;
      }

      final Map<String, dynamic> data = {
        'status': statusStr,
        'phase': phaseStr,
        'start_time_ms': startMs,
        'end_time_ms': endMs,
        'next_transition_ms': nextTransitionMs,
        'current_streak': streak,
        'latest_weight': weight ?? 0.0,
        'latest_body_fat': bodyFat ?? 0.0,
        'pref_widget_enabled': _settings.widgetEnabled,
        'pref_notification_enabled': _settings.notificationEnabled,
        'pref_countdown_enabled': _settings.liveCountdownEnabled,
        'pref_ring_enabled': _settings.progressRingEnabled,
        'pref_body_fat_enabled': _settings.bodyFatEnabled,
        'pref_weight_enabled': _settings.weightEnabled,
      };

      await _channel.invokeMethod('syncState', data);
    } catch (e) {
      // Ignore failures
    }
  }
}
