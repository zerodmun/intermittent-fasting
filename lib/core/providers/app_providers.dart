import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/helpers/streak_calculator.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';
import 'package:fast_flow/features/weight/domain/entities/weight_entry.dart';

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final box = HiveService.instance.userProfileBox;
  final subscription = box.watch(key: 'profile').listen((_) {
    ref.invalidateSelf();
  });
  ref.onDispose(() => subscription.cancel());
  return HiveService.instance.userProfile;
});

final fastingScheduleProvider = FutureProvider<FastingSchedule>((ref) async {
  final box = HiveService.instance.fastingScheduleBox;
  final subscription = box.watch(key: 'schedule').listen((_) {
    ref.invalidateSelf();
  });
  ref.onDispose(() => subscription.cancel());
  return HiveService.instance.fastingSchedule;
});

final fastingRecordsProvider = FutureProvider<List<FastingRecord>>((ref) async {
  final box = HiveService.instance.fastingRecordsBox;
  final subscription = box.watch().listen((_) {
    ref.invalidateSelf();
  });
  ref.onDispose(() => subscription.cancel());
  return HiveService.instance.allFastingRecords;
});

final weightEntriesProvider = FutureProvider<List<WeightEntry>>((ref) async {
  final box = HiveService.instance.weightEntriesBox;
  final subscription = box.watch().listen((_) {
    ref.invalidateSelf();
  });
  ref.onDispose(() => subscription.cancel());
  return HiveService.instance.allWeightEntries;
});

final streakProvider = Provider<StreakResult>((ref) {
  final records = ref.watch(fastingRecordsProvider).maybeWhen(
    data: (records) => records,
    orElse: () => <FastingRecord>[],
  );
  return StreakCalculator.calculate(records);
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});