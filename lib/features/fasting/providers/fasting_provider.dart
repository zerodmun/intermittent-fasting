import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/features/fasting/models/fasting_record.dart';
import 'package:fast_flow/features/fasting/models/fasting_schedule.dart';
import 'package:fast_flow/features/fasting/services/fasting_engine.dart';

export 'package:fast_flow/features/fasting/services/fasting_engine.dart' show FastingState, FastingStatus, FastingPhase;

final fastingEngineProvider = Provider<FastingEngine>((ref) {
  final engine = FastingEngine();
  engine.initialize();
  ref.onDispose(() {
    engine.dispose();
  });
  return engine;
});

final fastingStateProvider = StreamProvider<FastingState>((ref) {
  final engine = ref.watch(fastingEngineProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) {
    return engine.currentState!;
  }).distinct((a, b) => a.status == b.status &&
      a.elapsed == b.elapsed &&
      a.remaining == b.remaining &&
      a.progress == b.progress &&
      a.activeWindowStart == b.activeWindowStart &&
      a.activeWindowEnd == b.activeWindowEnd &&
      a.currentPhase == b.currentPhase &&
      a.nextTransition == b.nextTransition &&
      a.nextPhase == b.nextPhase);
});

final fastingStateProvider2 = NotifierProvider<FastingStateNotifier, FastingState?>(FastingStateNotifier.new);

class FastingStateNotifier extends Notifier<FastingState?> {
  @override
  FastingState? build() {
    final engine = ref.read(fastingEngineProvider);
    engine.addListener(_onEngineUpdate);
    ref.onDispose(() {
      engine.removeListener(_onEngineUpdate);
    });
    return engine.currentState;
  }

  void _onEngineUpdate() {
    final engine = ref.read(fastingEngineProvider);
    state = engine.currentState;
  }

  void refresh() {
    final engine = ref.read(fastingEngineProvider);
    engine.onRecordChanged();
  }

  void onScheduleChanged() {
    final engine = ref.read(fastingEngineProvider);
    engine.onScheduleChanged();
  }

  void saveSchedule(FastingSchedule schedule) {
    HiveService.instance.saveFastingSchedule(schedule);
    final engine = ref.read(fastingEngineProvider);
    engine.onScheduleChanged();
  }

  void logManualAction(String status) {
    final engine = ref.read(fastingEngineProvider);
    final now = DateTime.now();
    final schedule = HiveService.instance.fastingSchedule;
    final active = engine.getActiveWindow(now, schedule);

    final existing = _getRecordForDay(engine, active.cycleStartDate);
    if (existing != null) {
      existing.status = status;
      if (status == 'completed') {
        existing.endTime = now;
      }
      HiveService.instance.saveFastingRecord(existing);
    } else {
      final duration = active.endTime.difference(active.startTime).inMinutes;
      final record = FastingRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        planName: 'Daily Schedule',
        fastingMinutes: duration,
        eatingMinutes: 24 * 60 - duration,
        startTime: active.startTime,
        endTime: status == 'completed' ? now : active.endTime,
        status: status,
      );
      HiveService.instance.saveFastingRecord(record);
    }
    engine.onRecordChanged();
  }

  void editFastingRecord({
    required String id,
    required DateTime startTime,
    required DateTime endTime,
    required String status,
    String? note,
    String? reason,
  }) {
    final existing = HiveService.instance.fastingRecordsBox.get(id);
    if (existing != null) {
      existing.startTime = startTime;
      existing.endTime = endTime;
      existing.status = status;
      existing.note = note;
      existing.reason = reason;
      HiveService.instance.saveFastingRecord(existing);
      final engine = ref.read(fastingEngineProvider);
      engine.onRecordChanged();
    }
  }

  FastingRecord? _getRecordForDay(FastingEngine engine, DateTime date) {
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
}