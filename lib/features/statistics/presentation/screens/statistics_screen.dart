import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/features/food/presentation/providers/food_logs_provider.dart';
import 'package:fast_flow/features/statistics/presentation/screens/nutrition_details_screen.dart';
import 'package:fast_flow/features/statistics/presentation/screens/food_intake_summary_screen.dart';
import 'package:fast_flow/features/statistics/presentation/screens/weekly_detail_screen.dart';
import 'package:fast_flow/features/statistics/presentation/screens/monthly_calendar_screen.dart';
import 'package:fast_flow/features/statistics/presentation/screens/average_fast_detail_screen.dart';
import 'package:fast_flow/features/statistics/presentation/screens/exercise_screen.dart';
import 'package:fast_flow/features/statistics/presentation/providers/statistics_provider.dart';
import 'package:fast_flow/features/statistics/presentation/providers/workout_providers.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/stat_card.dart';
import 'package:fast_flow/shared/widgets/section_header.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '0h';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (minutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statisticsProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final foodLogs = ref.watch(foodLogsProvider);
    final records = ref.watch(fastingRecordsProvider);
    final workoutStats = ref.watch(workoutStatsProvider);
    final theme = Theme.of(context);

    // Calculate Daily Calorie Requirement
    final profile = profileAsync.maybeWhen(
      data: (p) => p,
      orElse: () => null,
    );

    int dailyCalories = 2000;
    if (profile != null) {
      final isMale = profile.gender.toLowerCase() == 'male';
      final bmr = isMale
          ? 10.0 * profile.weightKg + 6.25 * profile.heightCm - 5.0 * profile.ageYears + 5.0
          : 10.0 * profile.weightKg + 6.25 * profile.heightCm - 5.0 * profile.ageYears - 161.0;

      final activity = HiveService.instance.getSetting<String>('pref_activity_level') ?? 'Lightly Active';
      double multiplier = 1.375;
      switch (activity) {
        case 'Sedentary': multiplier = 1.2; break;
        case 'Lightly Active': multiplier = 1.375; break;
        case 'Moderately Active': multiplier = 1.55; break;
        case 'Very Active': multiplier = 1.725; break;
        case 'Extra Active': multiplier = 1.9; break;
      }

      final tdee = bmr * multiplier;
      String defaultGoal = 'Maintain Weight';
      if (profile.goalWeightKg < profile.weightKg) {
        defaultGoal = 'Lose Weight';
      } else if (profile.goalWeightKg > profile.weightKg) {
        defaultGoal = 'Gain Weight';
      }
      final goal = HiveService.instance.getSetting<String>('pref_weight_goal') ?? defaultGoal;
      double adjustment = 0.0;
      if (goal == 'Lose Weight') {
        adjustment = -500.0;
      } else if (goal == 'Gain Weight') {
        adjustment = 500.0;
      }

      dailyCalories = (tdee + adjustment).clamp(1200.0, 5000.0).round();
    }

    final totalFoodCalories = foodLogs.fold<double>(0.0, (sum, log) => sum + log.calories).round();

    // Calculate Total Fasting Parameters for overall summary card
    final completedRecords = records.where((r) => r.status == 'completed').toList();
    Duration totalFastingDuration = Duration.zero;
    for (final r in completedRecords) {
      totalFastingDuration += r.actualDuration;
    }
    final totalFastFormatted = _formatDuration(totalFastingDuration);

    // Calculate Weekly Completion count
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    int weeklyCompletedCount = 0;
    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final hasCompleted = records.any((r) =>
          r.status == 'completed' &&
          r.startTime.year == day.year &&
          r.startTime.month == day.month &&
          r.startTime.day == day.day);
      if (hasCompleted) {
        weeklyCompletedCount++;
      }
    }
    final weeklyCompletionPercent = ((weeklyCompletedCount / 7) * 100).round();

    // Calculate Monthly Trend
    final List<DateTime> mondaysOfCurrentMonth = [];
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    for (int d = 1; d <= lastDayOfMonth.day; d++) {
      final dayDate = DateTime(now.year, now.month, d);
      final m = dayDate.subtract(Duration(days: dayDate.weekday - 1));
      if (!mondaysOfCurrentMonth.contains(m)) {
        mondaysOfCurrentMonth.add(m);
      }
    }
    mondaysOfCurrentMonth.sort((a, b) => a.compareTo(b));

    final List<double> monthlyWeeklyPercentages = [];
    for (final monday in mondaysOfCurrentMonth) {
      int completedInWeek = 0;
      for (int i = 0; i < 7; i++) {
        final targetDay = monday.add(Duration(days: i));
        final hasCompleted = records.any((r) =>
            r.status == 'completed' &&
            r.startTime.year == targetDay.year &&
            r.startTime.month == targetDay.month &&
            r.startTime.day == targetDay.day);
        if (hasCompleted) {
          completedInWeek++;
        }
      }
      monthlyWeeklyPercentages.add((completedInWeek / 7.0) * 100.0);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(statisticsProvider);
          ref.invalidate(userProfileProvider);
          ref.invalidate(foodLogsProvider);
          ref.invalidate(fastingRecordsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              // Compact 4-Card Overview Grid
              _buildStatsGrid(
                context,
                stats,
                dailyCalories,
                totalFoodCalories,
                totalFastFormatted,
                workoutStats,
                theme,
              ),
              const SizedBox(height: AppSpacing.md),
              const SectionHeader(title: 'This Week'),
              const SizedBox(height: AppSpacing.xs),
              stats.totalSessions == 0
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
                      child: Center(
                        child: Text(
                          'No weekly data logged.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : _buildWeeklyChartCard(
                      context,
                      stats,
                      weeklyCompletedCount,
                      weeklyCompletionPercent,
                      theme,
                    ),
              const SizedBox(height: AppSpacing.md),
              const SectionHeader(title: 'Monthly Trend'),
              const SizedBox(height: AppSpacing.xs),
              stats.totalSessions == 0
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
                      child: Center(
                        child: Text(
                          'No monthly trend logged.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : _buildMonthlyChartCard(
                      context,
                      monthlyWeeklyPercentages,
                      mondaysOfCurrentMonth,
                      theme,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    StatsData stats,
    int dailyCalories,
    int totalFoodCalories,
    String totalFastFormatted,
    Map<String, dynamic> workoutStats,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        children: [
          // Row 1: Daily Calories & Total Calories Consumed
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.local_fire_department_rounded,
                    title: 'Daily Calories',
                    value: '$dailyCalories kcal',
                    iconColor: theme.colorScheme.primary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NutritionDetailsScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatCard(
                    icon: Icons.restaurant_menu_rounded,
                    title: 'Total Calories Consumed',
                    value: '$totalFoodCalories kcal',
                    iconColor: Colors.orangeAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FoodIntakeSummaryScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Row 2: Total Fast (Replaces Average Fast) & Exercises
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.timer_outlined,
                    title: 'Total Fast',
                    value: totalFastFormatted,
                    iconColor: theme.colorScheme.secondary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AverageFastDetailScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatCard(
                    icon: Icons.fitness_center_rounded,
                    title: 'Exercises',
                    value: '${workoutStats['totalDurationMinutes'] ?? 0} min',
                    iconColor: theme.colorScheme.tertiary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ExerciseScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChartCard(
    BuildContext context,
    StatsData stats,
    int completedCount,
    int completionPercent,
    ThemeData theme,
  ) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: AppCard.elevated(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const WeeklyDetailScreen(),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$completedCount / 7 Completed',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$completionPercent%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  maxY: 24,
                  barTouchData: const BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          if (value.toInt() >= 0 && value.toInt() < days.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                days[value.toInt()],
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(7, (i) {
                    final val = stats.weeklyData.length > i ? stats.weeklyData[i] : 0.0;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: val.clamp(0, 24).toDouble(),
                          color: val > 0 ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppSpacing.radiusSm),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyChartCard(
    BuildContext context,
    List<double> weeklyPercentages,
    List<DateTime> mondays,
    ThemeData theme,
  ) {
    final colorScheme = theme.colorScheme;
    final hasData = weeklyPercentages.any((v) => v > 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: AppCard.elevated(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MonthlyCalendarScreen(),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Weekly Completion rate',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 160,
              child: hasData
                  ? BarChart(
                      BarChartData(
                        maxY: 100,
                        barTouchData: const BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx >= 0 && idx < mondays.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'W${idx + 1}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(weeklyPercentages.length, (i) {
                          final pct = weeklyPercentages[i];
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: pct.clamp(0, 100).toDouble(),
                                color: pct > 0 ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                                width: 24,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(AppSpacing.radiusSm),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    )
                  : Center(
                      child: Text(
                        'No data available for this month.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
