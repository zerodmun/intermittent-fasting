import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/features/statistics/presentation/screens/monthly_calendar_screen.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('cal_align_test_');
    Hive.init(tempDir.path);
    await HiveService.instance.init();
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });


  group('Calendar Card Top Alignment Tests', () {
    testWidgets('MonthlyCalendarScreen renders calendar grid card with top alignment', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MonthlyCalendarScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));


      final AppCard cardWidget = tester.widget(find.byType(AppCard).first);
      expect(cardWidget.child, isA<Align>());

      final Align alignWidget = cardWidget.child as Align;
      expect(alignWidget.alignment, equals(Alignment.topCenter));

      final Column colWidget = alignWidget.child as Column;
      expect(colWidget.mainAxisAlignment, equals(MainAxisAlignment.start));

      await tester.pumpWidget(const SizedBox());
    });

  });
}
