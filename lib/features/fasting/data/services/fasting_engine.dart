import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:fast_flow/core/data/services/hive_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_state.dart';
import 'package:fast_flow/core/services/widget_sync_service.dart';

/// Singleton FastingEngine - Only ONE Timer.periodic for the entire app lifetime
class FastingEngine {
  static final FastingEngine _instance = FastingEngine._internal();
  factory FastingEngine() => _instance;
  FastingEngine._internal();

  FastingState? _currentState;
  Timer? _timer;
  final List<VoidCallback> _listeners = [];
  bool _isInitialized = false;

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
    _startTimer();
    _autoGenerateHistory();
    _tick();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
  }

  void _onTimerTick(Timer timer) {
    try {
      _tick();
    } catch (e, stack) {
      if (kDebugMode) {
        print('FastingEngine timer error: $e');
        print(stack);
      }
    }
  }

  void _tick() {
    final now = DateTime.now();
    final schedule = HiveService.instance.fastingSchedule;
    _currentState = _computeState(now, schedule);
    _notifyListeners();
    WidgetSyncService.instance.syncToNative();
  }

  void onScheduleChanged() {
    _tick();
  }

  void onRecordChanged() {
    _tick();
  }

  ActiveWindow getActiveWindow(DateTime now, FastingSchedule schedule) {
    return _getActiveWindow(now, schedule);
  }

  FastingState _computeState(DateTime now, FastingSchedule schedule) {
    final active = _getActiveWindow(now, schedule);
    final override = _getRecordForDay(active.cycleStartDate);

    final start = override?.startTime ?? active.startTime;
    final end = override?.endTime ?? active.endTime;

    FastingPhase currentPhase = active.phase;

    if (override != null) {
      if (now.isAfter(start) && now.isBefore(end)) {
        currentPhase = FastingPhase.fasting;
      } else {
        currentPhase = FastingPhase.eating;
      }
    }

    FastingStatus status;
    switch (currentPhase) {
      case FastingPhase.fasting:
        status = FastingStatus.fasting;
        break;
      case FastingPhase.eating:
        status = FastingStatus.eatingWindow;
        break;
    }

    // Check Preparing status (within 2 hours of fasting starting)
    if (currentPhase == FastingPhase.eating) {
      final daySched = schedule.getScheduleFor(active.cycleStartDate.weekday);
      final fastingStartTime = DateTime(
        active.cycleStartDate.year,
        active.cycleStartDate.month,
        active.cycleStartDate.day,
        daySched.fastHour,
        daySched.fastMin,
      );
      final diff = fastingStartTime.difference(now);
      if (diff.inMinutes > 0 && diff.inMinutes <= 120) {
        status = FastingStatus.preparing;
      }
    }

    // Check manual override status
    if (override != null) {
      if (override.status == 'completed') {
        if (now.isAfter(end)) {
          status = FastingStatus.completed;
        } else {
          status = FastingStatus.fasting;
        }
      } else if (override.status == 'skipped') {
        status = FastingStatus.skipped;
      } else if (override.status == 'cancelled') {
        status = FastingStatus.cancelled;
      }
    }

    Duration elapsed = now.difference(start);
    Duration remaining = end.difference(now);

    if (elapsed.isNegative) elapsed = Duration.zero;
    if (remaining.isNegative) remaining = Duration.zero;

    final total = end.difference(start);
    final progress = total.inSeconds > 0
        ? (elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    DateTime nextTransition;
    FastingPhase nextPhase;
    if (currentPhase == FastingPhase.fasting) {
      nextTransition = end;
      nextPhase = FastingPhase.eating;
    } else {
      final daySched = schedule.getScheduleFor(active.cycleStartDate.weekday);
      final nextFastingStart = DateTime(
        active.cycleStartDate.year,
        active.cycleStartDate.month,
        active.cycleStartDate.day,
        daySched.fastHour,
        daySched.fastMin,
      );
      if (now.isBefore(nextFastingStart)) {
        nextTransition = nextFastingStart;
      } else {
        nextTransition = nextFastingStart.add(const Duration(days: 1));
      }
      nextPhase = FastingPhase.fasting;
    }

    return FastingState(
      status: status,
      elapsed: elapsed,
      remaining: remaining,
      progress: progress,
      schedule: schedule,
      activeWindowStart: start,
      activeWindowEnd: end,
      currentPhase: currentPhase,
      nextTransition: nextTransition,
      nextPhase: nextPhase,
    );
  }

  ActiveWindow _getActiveWindow(DateTime now, FastingSchedule schedule) {
    // Check yesterday, today, tomorrow
    for (int offset = -1; offset <= 1; offset++) {
      final candidateDay = now.add(Duration(days: offset));
      final dateOnly = DateTime(candidateDay.year, candidateDay.month, candidateDay.day);
      final daySched = schedule.getScheduleFor(dateOnly.weekday);

      final eatingTime = DateTime(
        dateOnly.year,
        dateOnly.month,
        dateOnly.day,
        daySched.eatHour,
        daySched.eatMin,
      );
      final fastingTime = DateTime(
        dateOnly.year,
        dateOnly.month,
        dateOnly.day,
        daySched.fastHour,
        daySched.fastMin,
      );

      if (eatingTime.isBefore(fastingTime)) {
        final eatEnd = fastingTime;
        final fastEnd = eatingTime.add(const Duration(days: 1));

        if (now.isAfter(eatingTime) && now.isBefore(eatEnd)) {
          return ActiveWindow(
            startTime: eatingTime,
            endTime: eatEnd,
            phase: FastingPhase.eating,
            cycleStartDate: dateOnly,
          );
        }
        if (now.isAfter(fastingTime) && now.isBefore(fastEnd)) {
          return ActiveWindow(
            startTime: fastingTime,
            endTime: fastEnd,
            phase: FastingPhase.fasting,
            cycleStartDate: dateOnly,
          );
        }
      } else {
        final fastEnd = eatingTime;
        final eatEnd = fastingTime.add(const Duration(days: 1));

        if (now.isAfter(fastingTime) && now.isBefore(fastEnd)) {
          return ActiveWindow(
            startTime: fastingTime,
            endTime: fastEnd,
            phase: FastingPhase.fasting,
            cycleStartDate: dateOnly,
          );
        }
        if (now.isAfter(eatingTime) && now.isBefore(eatEnd)) {
          return ActiveWindow(
            startTime: eatingTime,
            endTime: eatEnd,
            phase: FastingPhase.eating,
            cycleStartDate: dateOnly,
          );
        }
      }
    }

    // Fallback
    final dateOnly = DateTime(now.year, now.month, now.day);
    return ActiveWindow(
      startTime: dateOnly.add(const Duration(hours: 9)),
      endTime: dateOnly.add(const Duration(hours: 17)),
      phase: FastingPhase.eating,
      cycleStartDate: dateOnly,
    );
  }

  FastingRecord? _getRecordForDay(DateTime date) {
    final records = HiveService.instance.allFastingRecords;
    for (final r in records) {
      if (r.startTime.year == date.year &&
          r.startTime.month == date.month &&
          r.startTime.day == date.day) {
        return r;
      }
    }
    return null;
  }

  Future<void> _autoGenerateHistory() async {
    final schedule = HiveService.instance.fastingSchedule;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastGenStr = HiveService.instance.getSetting<String>('last_history_gen_date');
    DateTime lastGen;

    if (lastGenStr != null) {
      lastGen = DateTime.parse(lastGenStr);
    } else {
      lastGen = today.subtract(const Duration(days: 7));
    }

    var loopDate = lastGen;

    while (loopDate.isBefore(today)) {
      final existing = _getRecordForDay(loopDate);
      if (existing == null) {
        final daySched = schedule.getScheduleFor(loopDate.weekday);
        final start = DateTime(
          loopDate.year,
          loopDate.month,
          loopDate.day,
          daySched.fastHour,
          daySched.fastMin,
        );
        final durationMinutes = _getFastingMinutes(loopDate.weekday, schedule);
        final record = FastingRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          planName: 'Daily Schedule',
          fastingMinutes: durationMinutes,
          eatingMinutes: _getEatingMinutes(loopDate.weekday, schedule),
          startTime: start,
          endTime: start.add(Duration(minutes: durationMinutes)),
          status: 'completed',
        );
        await HiveService.instance.saveFastingRecord(record);
      }
      loopDate = loopDate.add(const Duration(days: 1));
    }

    await HiveService.instance.setSetting('last_history_gen_date', today.toIso8601String());
  }

  int _getFastingMinutes(int weekday, FastingSchedule schedule) {
    final daySched = schedule.getScheduleFor(weekday);
    final start = daySched.fastHour * 60 + daySched.fastMin;
    var end = daySched.eatHour * 60 + daySched.eatMin;
    if (end < start) end += 24 * 60;
    return end - start;
  }

  int _getEatingMinutes(int weekday, FastingSchedule schedule) {
    final daySched = schedule.getScheduleFor(weekday);
    final start = daySched.eatHour * 60 + daySched.eatMin;
    var end = daySched.fastHour * 60 + daySched.fastMin;
    if (end < start) end += 24 * 60;
    return end - start;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _listeners.clear();
    _isInitialized = false;
  }
}

class ActiveWindow {
  final DateTime startTime;
  final DateTime endTime;
  final FastingPhase phase;
  final DateTime cycleStartDate;

  ActiveWindow({
    required this.startTime,
    required this.endTime,
    required this.phase,
    required this.cycleStartDate,
  });
}