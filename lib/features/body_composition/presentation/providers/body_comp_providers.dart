import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/features/weight/domain/entities/weight_entry.dart';
import 'package:fast_flow/features/weight/presentation/providers/weight_providers.dart';
import 'package:fast_flow/features/body_composition/data/services/body_comp_service.dart';
import 'package:fast_flow/features/body_composition/domain/entities/body_comp_result.dart';
import 'package:fast_flow/core/providers/app_providers.dart';

/// Provider for list of weight entries, watching weightProvider reactively.
final bodyCompEntriesProvider = Provider<List<WeightEntry>>((ref) {
  return ref.watch(weightProvider);
});

/// Provider for the latest weight entry.
final latestBodyCompEntryProvider = Provider<WeightEntry?>((ref) {
  final entries = ref.watch(bodyCompEntriesProvider);
  return entries.isNotEmpty ? entries.first : null;
});

/// Provider for the calculated body composition details of the latest entry.
final latestBodyCompResultProvider = Provider<BodyCompResult?>((ref) {
  final latestEntry = ref.watch(latestBodyCompEntryProvider);
  if (latestEntry == null) return null;

  final profile = ref.watch(userProfileProvider).maybeWhen(
        data: (p) => p,
        orElse: () => null,
      );
  if (profile == null) return null;

  return BodyCompService.calculate(
    profile: profile,
    weightKg: latestEntry.weightKg,
    waistCm: latestEntry.waistCm,
    neckCm: latestEntry.neckCm,
    hipCm: latestEntry.hipCm,
  );
});

/// Provider for changes in measurements since the previous entry.
class BodyCompChanges {
  final double weightChange;
  final double bodyFatChange;
  final double leanMassChange;
  final double fatMassChange;
  final double waistChange;
  final double chestChange;
  final double hipsChange;
  final double neckChange;

  const BodyCompChanges({
    this.weightChange = 0.0,
    this.bodyFatChange = 0.0,
    this.leanMassChange = 0.0,
    this.fatMassChange = 0.0,
    this.waistChange = 0.0,
    this.chestChange = 0.0,
    this.hipsChange = 0.0,
    this.neckChange = 0.0,
  });
}

final bodyCompChangesProvider = Provider<BodyCompChanges?>((ref) {
  final entries = ref.watch(bodyCompEntriesProvider);
  if (entries.length < 2) return null;

  final latest = entries.first;
  final prev = entries[1];

  final profile = ref.watch(userProfileProvider).maybeWhen(
        data: (p) => p,
        orElse: () => null,
      );
  if (profile == null) return null;

  final latestComp = BodyCompService.calculate(
    profile: profile,
    weightKg: latest.weightKg,
    waistCm: latest.waistCm,
    neckCm: latest.neckCm,
    hipCm: latest.hipCm,
  );

  final prevComp = BodyCompService.calculate(
    profile: profile,
    weightKg: prev.weightKg,
    waistCm: prev.waistCm,
    neckCm: prev.neckCm,
    hipCm: prev.hipCm,
  );

  final hasBF = latestComp.hasBodyFat && prevComp.hasBodyFat;

  return BodyCompChanges(
    weightChange: latest.weightKg - prev.weightKg,
    bodyFatChange: hasBF ? latestComp.bodyFatPercentage - prevComp.bodyFatPercentage : 0.0,
    leanMassChange: hasBF ? latestComp.leanBodyMassKg - prevComp.leanBodyMassKg : 0.0,
    fatMassChange: hasBF ? latestComp.fatMassKg - prevComp.fatMassKg : 0.0,
    waistChange: (latest.waistCm != null && prev.waistCm != null) ? latest.waistCm! - prev.waistCm! : 0.0,
    chestChange: (latest.chestCm != null && prev.chestCm != null) ? latest.chestCm! - prev.chestCm! : 0.0,
    hipsChange: (latest.hipCm != null && prev.hipCm != null) ? latest.hipCm! - prev.hipCm! : 0.0,
    neckChange: (latest.neckCm != null && prev.neckCm != null) ? latest.neckCm! - prev.neckCm! : 0.0,
  );
});
