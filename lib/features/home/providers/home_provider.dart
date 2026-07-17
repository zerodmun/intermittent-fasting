import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/helpers/streak_calculator.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/features/fasting/models/fasting_record.dart';
import 'package:fast_flow/features/onboarding/models/user_profile.dart';
import 'package:fast_flow/features/weight/models/weight_entry.dart';

final userProfileProvider = Provider<UserProfile?>((ref) {
  // We can listen to changes by reading from Hive.
  // In a real app, you might want to watch a state notifier,
  // but since profiles change rarely (mostly in settings),
  // we can read it directly.
  return HiveService.instance.userProfile;
});

final fastingRecordsProvider = Provider<List<FastingRecord>>((ref) {
  // Watch fasting timer provider to trigger updates when records change
  // Actually, we should trigger when records are added.
  // For simplicity, we read from box values.
  return HiveService.instance.allFastingRecords;
});

final weightEntriesProvider = Provider<List<WeightEntry>>((ref) {
  return HiveService.instance.allWeightEntries;
});

final streakProvider = Provider<StreakResult>((ref) {
  final records = ref.watch(fastingRecordsProvider);
  return StreakCalculator.calculate(records);
});
