import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/statistics/presentation/providers/statistics_provider.dart';
import 'package:fast_flow/features/statistics/presentation/screens/statistics_screen.dart';
import 'package:fast_flow/features/statistics/presentation/screens/average_fast_detail_screen.dart';
import 'package:fast_flow/shared/widgets/stat_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('stats_redesign_refinement_test_');
    Hive.init(tempDir.path);
    await HiveService.instance.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    await HiveService.instance.fastingRecordsBox.clear();
  });

  group('Refined Total Fast Implementation Unit & Widget Tests', () {
    test('Total Fast, Longest, Shortest, Total Fasts, and Skip Count calculation logic', () async {
      // Create test fasting records for August 2026
      // Fast #1 = 16h (Aug 1)
      final r1 = FastingRecord(
        id: 'r1',
        planName: '16:8',
        fastingMinutes: 960,
        eatingMinutes: 480,
        startTime: DateTime(2026, 8, 1, 8, 0),
        endTime: DateTime(2026, 8, 1, 24, 0),
        status: 'completed',
      );
      // Fast #2 = 18h (Aug 2)
      final r2 = FastingRecord(
        id: 'r2',
        planName: '18:6',
        fastingMinutes: 1080,
        eatingMinutes: 360,
        startTime: DateTime(2026, 8, 2, 0, 0),
        endTime: DateTime(2026, 8, 2, 18, 0),
        status: 'completed',
      );
      // Fast #3 = 14h (Aug 2)
      final r3 = FastingRecord(
        id: 'r3',
        planName: '14:10',
        fastingMinutes: 840,
        eatingMinutes: 600,
        startTime: DateTime(2026, 8, 2, 10, 0),
        endTime: DateTime(2026, 8, 2, 24, 0),
        status: 'completed',
      );
      // Fast #4 = 20h (Aug 4)
      final r4 = FastingRecord(
        id: 'r4',
        planName: '20:4',
        fastingMinutes: 1200,
        eatingMinutes: 240,
        startTime: DateTime(2026, 8, 4, 4, 0),
        endTime: DateTime(2026, 8, 5, 0, 0),
        status: 'completed',
      );
      // Skipped Fast (Aug 5)
      final r5 = FastingRecord(
        id: 'r5',
        planName: '16:8',
        fastingMinutes: 960,
        eatingMinutes: 480,
        startTime: DateTime(2026, 8, 5, 8, 0),
        endTime: null,
        status: 'skipped',
      );

      await HiveService.instance.saveFastingRecord(r1);
      await HiveService.instance.saveFastingRecord(r2);
      await HiveService.instance.saveFastingRecord(r3);
      await HiveService.instance.saveFastingRecord(r4);
      await HiveService.instance.saveFastingRecord(r5);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set filter to August 2026
      container.read(statsPeriodFilterProvider.notifier).setYear(2026);
      container.read(statsPeriodFilterProvider.notifier).setMonth(8);
      container.read(statsPeriodFilterProvider.notifier).setMode(StatsPeriodMode.month);

      final periodStats = container.read(periodStatsProvider);

      // Total Fast = 16h + 18h + 14h + 20h = 68h
      expect(periodStats.totalFastDuration.inHours, equals(68));
      expect(periodStats.longestFastDuration?.inHours, equals(20));
      expect(periodStats.shortestFastDuration?.inHours, equals(14));
      expect(periodStats.totalFasts, equals(4));
      expect(periodStats.skipCount, equals(1));
    });

    test('Empty period displays zero/empty values (0h, -, 0)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(statsPeriodFilterProvider.notifier).setYear(2020);
      container.read(statsPeriodFilterProvider.notifier).setMonth(7);
      container.read(statsPeriodFilterProvider.notifier).setMode(StatsPeriodMode.month);

      final periodStats = container.read(periodStatsProvider);

      expect(periodStats.totalFastDuration, equals(Duration.zero));
      expect(periodStats.longestFastDuration, isNull);
      expect(periodStats.shortestFastDuration, isNull);
      expect(periodStats.totalFasts, equals(0));
      expect(periodStats.skipCount, equals(0));
    });

    testWidgets('1. Stats page contains exactly 4 summary cards (Compact Overview)', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: StatisticsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StatCard), findsNWidgets(4));
      expect(find.text('Daily Calories'), findsOneWidget);
      expect(find.text('Total Calories Consumed'), findsOneWidget);
      expect(find.text('Total Fast'), findsOneWidget);
      expect(find.text('Exercises'), findsOneWidget);
    });

    testWidgets('2 & 3. Total Fast card opens Total Fast detail page', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: StatisticsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Average Fast'), findsNothing);
      final totalFastCardFinder = find.text('Total Fast');
      expect(totalFastCardFinder, findsOneWidget);

      await tester.tap(totalFastCardFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AverageFastDetailScreen), findsOneWidget);
    });

    testWidgets('4. Total Fast detail page displays 5 metrics only, NO Fasting Days, and restyled DropdownButtonFormField filter', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AverageFastDetailScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 5 metrics present
      expect(find.text('Total Fast'), findsWidgets);
      expect(find.text('Longest Fast'), findsOneWidget);
      expect(find.text('Shortest Fast'), findsOneWidget);
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.text('Total Fasts'), findsOneWidget);

      // Fasting Days is completely removed
      expect(find.text('Fasting Days'), findsNothing);

      // App standard DropdownButtonFormField controls present for filter
      expect(find.byType(DropdownButtonFormField<StatsPeriodMode>), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(2)); // Month & Year dropdowns
    });
  });
}
