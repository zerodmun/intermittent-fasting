import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fast_flow/core/helpers/body_comp_calculator.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/features/weight/models/weight_entry.dart';

class WeightNotifier extends Notifier<List<WeightEntry>> {
  @override
  List<WeightEntry> build() {
    return HiveService.instance.allWeightEntries;
  }

  void refresh() {
    state = HiveService.instance.allWeightEntries;
  }

  Future<void> addEntry(
    double weightKg, {
    String? note,
    DateTime? date,
    double? waistCm,
    double? neckCm,
    double? hipCm,
  }) async {
    final profile = HiveService.instance.userProfile;
    double? bf;
    double? lbm;
    double? fm;
    double? calculatedBmi;

    if (profile != null && waistCm != null && neckCm != null) {
      final res = BodyCompCalculator.calculate(
        gender: profile.gender,
        heightCm: profile.heightCm,
        weightKg: weightKg,
        waistCm: waistCm,
        neckCm: neckCm,
        hipCm: hipCm ?? 0.0,
        ageYears: profile.ageYears,
      );
      bf = res.bodyFatPercentage;
      lbm = res.leanBodyMassKg;
      fm = res.fatMassKg;
      calculatedBmi = res.bmi;
    } else if (profile != null) {
      calculatedBmi = double.parse(
        (weightKg / ((profile.heightCm / 100) * (profile.heightCm / 100)))
            .toStringAsFixed(1),
      );
    }

    final entry = WeightEntry(
      id: const Uuid().v4(),
      weightKg: weightKg,
      date: date ?? DateTime.now(),
      note: note,
      waistCm: waistCm,
      neckCm: neckCm,
      hipCm: hipCm,
      bodyFatPercentage: bf,
      bmi: calculatedBmi,
      leanMassKg: lbm,
      fatMassKg: fm,
    );

    // Save weight entry
    await HiveService.instance.saveWeightEntry(entry);

    // Update current weight in UserProfile as well
    if (profile != null) {
      final updatedProfile = profile.copyWith(weightKg: weightKg);
      await HiveService.instance.saveUserProfile(updatedProfile);
    }

    refresh();
  }

  Future<void> updateEntry(
    String id,
    double weightKg, {
    String? note,
    DateTime? date,
    double? waistCm,
    double? neckCm,
    double? hipCm,
  }) async {
    final profile = HiveService.instance.userProfile;
    double? bf;
    double? lbm;
    double? fm;
    double? calculatedBmi;

    if (profile != null && waistCm != null && neckCm != null) {
      final res = BodyCompCalculator.calculate(
        gender: profile.gender,
        heightCm: profile.heightCm,
        weightKg: weightKg,
        waistCm: waistCm,
        neckCm: neckCm,
        hipCm: hipCm ?? 0.0,
        ageYears: profile.ageYears,
      );
      bf = res.bodyFatPercentage;
      lbm = res.leanBodyMassKg;
      fm = res.fatMassKg;
      calculatedBmi = res.bmi;
    } else if (profile != null) {
      calculatedBmi = double.parse(
        (weightKg / ((profile.heightCm / 100) * (profile.heightCm / 100)))
            .toStringAsFixed(1),
      );
    }

    final existing = HiveService.instance.weightEntriesBox.get(id);
    if (existing != null) {
      final updated = existing.copyWith(
        weightKg: weightKg,
        date: date ?? existing.date,
        note: note,
        waistCm: waistCm,
        neckCm: neckCm,
        hipCm: hipCm,
        bodyFatPercentage: bf,
        bmi: calculatedBmi,
        leanMassKg: lbm,
        fatMassKg: fm,
      );
      await HiveService.instance.saveWeightEntry(updated);
      refresh();
    }
  }

  Future<void> deleteEntry(String id) async {
    await HiveService.instance.deleteWeightEntry(id);
    refresh();
  }
}

final weightProvider = NotifierProvider<WeightNotifier, List<WeightEntry>>(WeightNotifier.new);

final currentWeightProvider = Provider<double?>((ref) {
  final entries = ref.watch(weightProvider);
  return entries.isNotEmpty ? entries.first.weightKg : null;
});

final goalWeightProvider = Provider<double?>((ref) {
  return HiveService.instance.userProfile?.goalWeightKg;
});

final currentBodyCompProvider = Provider<BodyCompResult?>((ref) {
  final entries = ref.watch(weightProvider);
  final profile = HiveService.instance.userProfile;
  if (entries.isEmpty || profile == null) return null;

  final latest = entries.first;
  if (latest.waistCm == null || latest.neckCm == null) {
    // Return standard calculation with default placeholders if no waist/neck logged yet
    return BodyCompCalculator.calculate(
      gender: profile.gender,
      heightCm: profile.heightCm,
      weightKg: latest.weightKg,
      waistCm: profile.targetWaist > 0 ? profile.targetWaist : 80.0,
      neckCm: 38.0,
      hipCm: profile.gender.toLowerCase() == 'female' ? 95.0 : 0.0,
      ageYears: profile.ageYears,
    );
  }

  return BodyCompCalculator.calculate(
    gender: profile.gender,
    heightCm: profile.heightCm,
    weightKg: latest.weightKg,
    waistCm: latest.waistCm!,
    neckCm: latest.neckCm!,
    hipCm: latest.hipCm ?? 0.0,
    ageYears: profile.ageYears,
  );
});
