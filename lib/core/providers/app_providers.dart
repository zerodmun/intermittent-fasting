import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/helpers/streak_calculator.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';
import 'package:fast_flow/features/weight/domain/entities/weight_entry.dart';

class CurrentDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (state != today) {
        state = today;
      }
    });
    ref.onDispose(() => timer.cancel());
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

final currentDateProvider = NotifierProvider<CurrentDateNotifier, DateTime>(
  CurrentDateNotifier.new,
);

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

class FastingRecordsNotifier extends Notifier<List<FastingRecord>> {
  @override
  List<FastingRecord> build() {
    final box = HiveService.instance.fastingRecordsBox;
    final subscription = box.watch().listen((_) {
      state = HiveService.instance.allFastingRecords;
    });
    ref.onDispose(() => subscription.cancel());
    return HiveService.instance.allFastingRecords;
  }
}

final fastingRecordsProvider = NotifierProvider<FastingRecordsNotifier, List<FastingRecord>>(
  FastingRecordsNotifier.new,
);

final weightEntriesProvider = FutureProvider<List<WeightEntry>>((ref) async {
  final box = HiveService.instance.weightEntriesBox;
  final subscription = box.watch().listen((_) {
    ref.invalidateSelf();
  });
  ref.onDispose(() => subscription.cancel());
  return HiveService.instance.allWeightEntries;
});

final streakProvider = Provider<StreakResult>((ref) {
  final records = ref.watch(fastingRecordsProvider);
  return StreakCalculator.calculate(records);
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});