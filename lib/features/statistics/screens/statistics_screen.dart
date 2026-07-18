import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/duration_extensions.dart';
import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/core/data/services/hive_service.dart';
import 'package:fast_flow/features/food_scanner/providers/food_logs_provider.dart';
import 'package:fast_flow/features/statistics/screens/nutrition_details_screen.dart';
import 'package:fast_flow/features/statistics/screens/food_intake_summary_screen.dart';
import 'package:fast_flow/features/statistics/providers/statistics_provider.dart';
import '../../../shared/widgets/animated_progress_ring.dart';
import '../../../shared/widgets/empty_state.dart';
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
    final theme = Theme.of(context);

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(statisticsProvider);
          ref.invalidate(userProfileProvider);
          ref.invalidate(foodLogsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatsGrid(context, stats, dailyCalories, totalFoodCalories, theme),
              const SectionHeader(title: 'Completion Rate'),
              stats.totalSessions == 0
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
                      child: EmptyState(
                        icon: Icons.analytics_outlined,
                        title: 'No fasting data',
                        subtitle: 'Complete a fasting session to see success rate.',
                      ),
                    )
                  : _buildCompletionCard(context, stats),
              const SectionHeader(title: 'This Week'),
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
                  : _buildWeeklyChart(context, stats),
              const SectionHeader(title: 'Monthly Trend'),
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
                  : _buildMonthlyChart(context, stats),
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
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.15,
        children: [
          StatCard(
            icon: Icons.local_fire_department_rounded,
            label: 'Daily Calories',
            value: '$dailyCalories kcal',
            subtitle: 'Recommended daily intake',
            color: theme.colorScheme.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NutritionDetailsScreen(),
                ),
              );
            },
          ),
          StatCard(
            icon: Icons.restaurant_menu_rounded,
            label: 'Total Calories Consumed',
            value: '$totalFoodCalories kcal',
            subtitle: 'From Food Scanner',
            color: Colors.orangeAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FoodIntakeSummaryScreen(),
                ),
              );
            },
          ),
          StatCard(
            icon: Icons.timer_outlined,
            label: 'Avg Duration',
            value: Duration(minutes: stats.averageDurationMinutes.round()).toReadable,
            color: theme.colorScheme.secondary,
          ),
          StatCard(
            icon: Icons.hourglass_empty_rounded,
            label: 'Total Fasted',
            value: '${stats.totalFastingHours.toStringAsFixed(1)}h',
            color: theme.colorScheme.tertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCard(BuildContext context, StatsData stats) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: AppCard.elevated(
        child: Row(
          children: [
            AnimatedProgressRing(
              progress: stats.completionRate / 100,
              size: 90,
              strokeWidth: 8,
              color: context.colors.success,
              backgroundColor: context.colors.success.withValues(alpha: 0.15),
              child: Text(
                '${stats.completionRate.toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xlg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Success Rate',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'You completed ${stats.totalCompleted} out of ${stats.totalSessions} started fasting cycles.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(BuildContext context, StatsData stats) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasData = stats.weeklyData.any((v) => v > 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: AppCard.elevated(
        child: SizedBox(
          height: 200,
          child: hasData
              ? BarChart(
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
                )
              : Center(
                  child: Text(
                    'No weekly data logged.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMonthlyChart(BuildContext context, StatsData stats) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasData = stats.monthlyData.any((v) => v > 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: AppCard.elevated(
        child: SizedBox(
          height: 200,
          child: hasData
              ? LineChart(
                  LineChartData(
                    lineTouchData: const LineTouchData(enabled: true),
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(30, (index) {
                          return FlSpot(index.toDouble(), stats.monthlyData[index]);
                        }),
                        isCurved: true,
                        color: colorScheme.primary,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: colorScheme.primary.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Text(
                    'No monthly trend logged.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
        ),
      ),
    );
  }
}
