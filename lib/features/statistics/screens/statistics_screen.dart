import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/constants/app_spacing.dart';
import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/core/data/services/hive_service.dart';
import 'package:fast_flow/features/food_scanner/providers/food_logs_provider.dart';
import 'package:fast_flow/features/statistics/screens/nutrition_details_screen.dart';
import 'package:fast_flow/features/statistics/screens/food_intake_summary_screen.dart';
import 'package:fast_flow/features/statistics/screens/weekly_detail_screen.dart';
import 'package:fast_flow/features/statistics/screens/monthly_calendar_screen.dart';
import 'package:fast_flow/features/statistics/screens/average_fast_detail_screen.dart';
import 'package:fast_flow/features/statistics/providers/statistics_provider.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/section_header.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statisticsProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final foodLogs = ref.watch(foodLogsProvider);
    final recordsAsync = ref.watch(fastingRecordsProvider);
    final theme = Theme.of(context);

    final records = recordsAsync.maybeWhen(
      data: (r) => r,
      orElse: () => <FastingRecord>[],
    );

    // Calculate Daily Calorie Requirement
    final profile = profileAsync.maybeWhen(
      data: (p) => p,
      orElse: () => null,
    );

    int dailyCalories = 2000; // default fallback
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

    // Calculate Total Calories Consumed
    final totalFoodCalories = foodLogs.fold<double>(0.0, (sum, log) => sum + log.calories).round();

    // Calculate Average Fasting Parameters
    final completedRecords = records.where((r) => r.status == 'completed').toList();
    final totalCompleted = completedRecords.length;
    Duration totalFastingDuration = Duration.zero;
    for (final r in completedRecords) {
      totalFastingDuration += r.actualDuration;
    }
    final avgFastingDuration = totalCompleted > 0
        ? Duration(minutes: (totalFastingDuration.inMinutes / totalCompleted).round())
        : Duration.zero;

    String formatDuration(Duration d) {
      if (d == Duration.zero) return '-';
      final hours = d.inHours;
      final minutes = d.inMinutes % 60;
      if (minutes == 0) {
        return '${hours}h';
      }
      return '${hours}h ${minutes}m';
    }

    final avgFastFormatted = formatDuration(avgFastingDuration);

    // Calculate Weekly Completion count and rate using real records
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

    // Calculate Monthly Trend grouped by week
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
              _buildStatsGrid(
                context,
                stats,
                dailyCalories,
                totalFoodCalories,
                avgFastFormatted,
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
    String avgFastFormatted,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        children: [
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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.timer_outlined,
                    title: 'Average Fast',
                    value: avgFastFormatted,
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
                    icon: Icons.hourglass_empty_rounded,
                    title: 'Total Fasted',
                    value: '${stats.totalFastingHours.toStringAsFixed(1)}h',
                    iconColor: theme.colorScheme.tertiary,
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
              child: _buildWeeklyChartContent(context, stats, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChartContent(BuildContext context, StatsData stats, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final hasData = stats.weeklyData.any((v) => v > 0);

    if (!hasData) {
      return Center(
        child: Text(
          'No weekly data logged.',
          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 24,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colorScheme.primaryContainer,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(1)}h',
                theme.textTheme.labelMedium!.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                final idx = value.toInt();
                if (idx >= 0 && idx < days.length) {
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      days[idx],
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: stats.weeklyData[index],
                color: colorScheme.primary,
                width: 14,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusSm),
                ),
              ),
            ],
          );
        }),
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
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => colorScheme.primaryContainer,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${rod.toY.round()}%',
                                theme.textTheme.labelMedium!.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx >= 0 && idx < mondays.length) {
                                  return SideTitleWidget(
                                    meta: meta,
                                    child: Text(
                                      'W${idx + 1}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(mondays.length, (idx) {
                          return BarChartGroupData(
                            x: idx,
                            barRods: [
                              BarChartRodData(
                                toY: weeklyPercentages[idx],
                                color: colorScheme.secondary,
                                width: 16,
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
                        'No monthly trend logged.',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
