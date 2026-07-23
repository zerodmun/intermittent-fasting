import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/features/weight/domain/entities/weight_entry.dart';
import 'package:fast_flow/features/weight/domain/entities/body_comp_result.dart';
import 'package:fast_flow/features/weight/data/services/body_comp_calculator.dart';
import 'package:fast_flow/core/services/widget_sync_service.dart';

class WeightNotifier extends Notifier<List<WeightEntry>> {
  @override
  List<WeightEntry> build() {
    return HiveService.instance.allWeightEntries;
  }

  Future<void> addEntry(WeightEntry entry) async {
    await HiveService.instance.saveWeightEntry(entry);
    state = HiveService.instance.allWeightEntries;
    WidgetSyncService.instance.syncToNative();
  }

  Future<void> updateEntry(WeightEntry entry) async {
    await HiveService.instance.saveWeightEntry(entry);
    state = HiveService.instance.allWeightEntries;
    WidgetSyncService.instance.syncToNative();
  }

  Future<void> deleteEntry(String id) async {
    await HiveService.instance.deleteWeightEntry(id);
    state = HiveService.instance.allWeightEntries;
    WidgetSyncService.instance.syncToNative();
  }
}

final weightProvider = NotifierProvider<WeightNotifier, List<WeightEntry>>(
  WeightNotifier.new,
);

final currentWeightProvider = Provider<WeightEntry?>((ref) {
  final entries = ref.watch(weightProvider);
  return entries.isNotEmpty ? entries.first : null;
});

final goalWeightProvider = Provider<double?>((ref) {
  final profile = HiveService.instance.userProfile;
  return profile?.goalWeightKg;
});

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