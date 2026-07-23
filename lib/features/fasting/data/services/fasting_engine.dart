import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_state.dart';
import 'package:fast_flow/core/services/widget_sync_service.dart';
import 'package:fast_flow/core/services/logger_service.dart';

import 'timeline_generator.dart';
import 'session_resolver.dart';
import 'history_generator.dart';

/// Singleton FastingEngine - Only ONE Timer.periodic for the entire app lifetime
class FastingEngine {
  static final FastingEngine _instance = FastingEngine._internal();
  factory FastingEngine() => _instance;
  FastingEngine._internal();

  FastingState? _currentState;
  Timer? _timer;
  final List<VoidCallback> _listeners = [];
  bool _isInitialized = false;

  List<TimelineSession> _cachedTimeline = [];
  DateTime? _lastTimelineGenDay;
  FastingSchedule? _lastSchedule;

  FastingState? get currentState => _currentState;

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    _tick();
    _startTimer();
    _autoGenerateHistory();

    // Reactively watch schedule updates to clear cache and recalculate active sessions
    HiveService.instance.fastingScheduleBox.watch(key: 'schedule').listen((_) {
      onScheduleChanged();
    });

    // Reactively watch record changes (add, update, delete) to update elapsed/remaining/progress
    HiveService.instance.fastingRecordsBox.watch().listen((_) {
      onRecordChanged();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
  }

  void _onTimerTick(Timer timer) {
    try {
      _tick();
    } catch (e, stack) {
      LoggerService.e('FastingEngine timer error', e, stack);
    }
  }

  void _tick() {
    final now = DateTime.now();
    _ensureTimeline();
    _currentState = SessionResolver.resolveState(
      now: now,
      sessions: _cachedTimeline,
      getOverrideRecord: getRecordForSession,
      schedule: HiveService.instance.fastingSchedule,
    );

    if (_currentState != null) {
      final offsetHours = now.timeZoneOffset.inHours;
      final offsetMins = (now.timeZoneOffset.inMinutes.abs() % 60);
      final offsetStr = 'UTC${offsetHours >= 0 ? '+' : '-'}${offsetHours.abs()}:${offsetMins.toString().padLeft(2, '0')}';
      final sched = HiveService.instance.fastingSchedule;
      final scheduleStr = sched.dailySchedules.entries.map((e) => '[Day ${e.key}: Fast ${e.value.fastTimeFormatted}, Eat ${e.value.eatTimeFormatted}]').join('\n');

      LoggerService.d(
        'FastingEngine tick:\n'
        '---------------------------\n'
        'NOW LOCAL: $now\n'
        'NOW UTC: ${now.toUtc()}\n'
        'TIMEZONE: $offsetStr\n'
        'ACTIVE SESSION START: ${_currentState!.activeWindowStart}\n'
        'ACTIVE SESSION END: ${_currentState!.activeWindowEnd}\n'
        'ELAPSED: ${_currentState!.elapsed}\n'
        'REMAINING: ${_currentState!.remaining}\n'
        'CURRENT STATUS: ${_currentState!.status}\n'
        'WEEKLY SCHEDULE USED:\n$scheduleStr\n'
        '---------------------------'
      );
    }

    _notifyListeners();
    WidgetSyncService.instance.syncToNative();
  }

  void _ensureTimeline() {
    final now = DateTime.now();
    final schedule = HiveService.instance.fastingSchedule;
    final today = DateTime(now.year, now.month, now.day);

    if (_cachedTimeline.isEmpty ||
        _lastTimelineGenDay != today ||
        _lastSchedule != schedule) {
      _cachedTimeline = TimelineGenerator.generateTimeline(
        schedule: schedule,
        centerDate: now,
        daysBefore: 7,
        daysAfter: 14,
      );
      _lastTimelineGenDay = today;
      _lastSchedule = schedule;
    }
  }

  void onScheduleChanged() {
    _cachedTimeline.clear(); // Force timeline regeneration next tick
    _tick();
  }

  void onRecordChanged() {
    _tick();
  }

  Future<void> _autoGenerateHistory() async {
    final schedule = HiveService.instance.fastingSchedule;
    await HistoryGenerator.autoGenerateHistory(
      schedule: schedule,
      getRecordForSession: getRecordForSession,
    );
  }

  /// Retained for compatibility but updated to search the timeline-based records.
  FastingRecord? getRecordForSession(DateTime expectedStart) {
    // 1. Direct key match (deterministic ID format)
    final key = 'session_${expectedStart.millisecondsSinceEpoch}';
    final recordByKey = HiveService.instance.fastingRecordsBox.get(key);
    if (recordByKey != null) {
      return recordByKey;
    }

    final records = HiveService.instance.allFastingRecords;
    FastingRecord? bestMatch;
    int minDiffMs = 999999999999; // large number

    for (final r in records) {
      // 2. Direct calendar day match
      final sameDay = r.startTime.year == expectedStart.year &&
          r.startTime.month == expectedStart.month &&
          r.startTime.day == expectedStart.day;
      if (sameDay) {
        return r;
      }

      // 3. Proximity match within 12 hours
      final diffMs = (r.startTime.millisecondsSinceEpoch - expectedStart.millisecondsSinceEpoch).abs();
      if (diffMs < 12 * 60 * 60 * 1000 && diffMs < minDiffMs) {
        minDiffMs = diffMs;
        bestMatch = r;
      }
    }
    return bestMatch;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _listeners.clear();
    _isInitialized = false;
  }
}