import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/data/services/hive_service.dart';
import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';

final historyProvider = FutureProvider<List<FastingRecord>>((ref) async {
  return ref.watch(fastingRecordsProvider.future);
});

final historyProviderNotifier = NotifierProvider<HistoryNotifier, List<FastingRecord>>(HistoryNotifier.new);

class HistoryNotifier extends Notifier<List<FastingRecord>> {
  @override
  List<FastingRecord> build() {
    return HiveService.instance.allFastingRecords;
  }

  void refresh() {
    state = HiveService.instance.allFastingRecords;
  }

  Future<void> deleteRecord(String id) async {
    await HiveService.instance.deleteFastingRecord(id);
    refresh();
  }

  Future<void> saveRecord(FastingRecord record) async {
    await HiveService.instance.saveFastingRecord(record);
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