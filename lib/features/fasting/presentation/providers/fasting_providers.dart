import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/data/services/hive_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_state.dart';
import 'package:fast_flow/features/fasting/data/services/fasting_engine.dart';
import 'package:fast_flow/features/weight/domain/entities/body_comp_result.dart';
import 'package:fast_flow/features/weight/data/services/body_comp_calculator.dart';

final fastingEngineProvider = Provider<FastingEngine>((ref) {
  final engine = FastingEngine();
  engine.initialize();
  ref.onDispose(() {
    engine.dispose();
  });
  return engine;
});

final fastingStateNotifierProvider = NotifierProvider<FastingStateNotifier, FastingState?>(
  FastingStateNotifier.new,
);

class FastingStateNotifier extends Notifier<FastingState?> {
  @override
  FastingState? build() {
    final engine = ref.read(fastingEngineProvider);
    state = engine.currentState;
    engine.addListener(_onEngineUpdate);
    ref.onDispose(() => engine.removeListener(_onEngineUpdate));
    return state;
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

  void logManualAction(String status) {
    final engine = ref.read(fastingEngineProvider);
    final now = DateTime.now();
    final schedule = HiveService.instance.fastingSchedule;
    final active = engine.getActiveWindow(now, schedule);

    final existing = _getRecordForDay(active.cycleStartDate);
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
}

final currentBodyCompProvider = FutureProvider<BodyCompResult?>((ref) async {
  final profile = HiveService.instance.userProfile;
  if (profile == null) return null;
  final entries = HiveService.instance.allWeightEntries;
  if (entries.isEmpty) return null;

  final latest = entries.first;
  return BodyCompCalculator.calculate(
    profile: profile,
    weightKg: latest.weightKg,
    waistCm: latest.waistCm,
    neckCm: latest.neckCm,
    hipCm: latest.hipCm,
    gender: profile.gender,
  );
});