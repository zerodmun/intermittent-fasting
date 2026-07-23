import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/statistics/presentation/providers/statistics_provider.dart';

final historyProvider = Provider<List<FastingRecord>>((ref) {
  return ref.watch(fastingRecordsProvider);
});

final historyProviderNotifier = NotifierProvider<HistoryNotifier, List<FastingRecord>>(HistoryNotifier.new);

class HistoryNotifier extends Notifier<List<FastingRecord>> {
  @override
  List<FastingRecord> build() {
    return ref.watch(fastingRecordsProvider);
  }

  void refresh() {
    state = HiveService.instance.allFastingRecords;
  }

  Future<void> deleteRecord(String id) async {
    await HiveService.instance.deleteFastingRecord(id);
    ref.invalidate(fastingRecordsProvider);
    ref.invalidate(statisticsProvider);
    refresh();
  }

  Future<void> saveRecord(FastingRecord record) async {
    await HiveService.instance.saveFastingRecord(record);
    ref.invalidate(fastingRecordsProvider);
    ref.invalidate(statisticsProvider);
    refresh();
  }
}

class HistoryViewModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final historyViewModeProvider = NotifierProvider<HistoryViewModeNotifier, bool>(HistoryViewModeNotifier.new);

class SelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  void select(DateTime day) => state = day;
}

final selectedDayProvider = NotifierProvider<SelectedDayNotifier, DateTime>(SelectedDayNotifier.new);