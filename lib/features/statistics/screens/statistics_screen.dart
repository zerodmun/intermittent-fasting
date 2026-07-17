import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fast_flow/core/constants/app_colors.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/core/extensions/duration_extensions.dart';
import 'package:fast_flow/features/statistics/providers/statistics_provider.dart';
import 'package:fast_flow/shared/widgets/animated_progress_ring.dart';
import 'package:fast_flow/shared/widgets/empty_state.dart';
import 'package:fast_flow/shared/widgets/section_header.dart';
import 'package:fast_flow/shared/widgets/stat_tile.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statisticsProvider);
    final theme = Theme.of(context);

    if (stats.totalSessions == 0) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Statistics'),
        ),
        body: const EmptyState(
          icon: Icons.bar_chart,
          title: 'No statistics yet',
          subtitle: 'Complete your first fast to see analytics graphs.',
          illustrationPath: 'assets/illustrations/empty_stats.svg',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatsGrid(context, stats, theme),
            const SectionHeader(title: 'Completion Rate'),
            _buildCompletionCard(context, stats),
            const SectionHeader(title: 'This Week (Fasting Hours)'),
            _buildWeeklyChart(context, stats),
            const SectionHeader(title: 'Monthly Trend'),
            _buildMonthlyChart(context, stats),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, StatsData stats, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.3,
        children: [
          StatTile(
            icon: Icons.local_fire_department,
            label: 'Current Streak',
            value: '${stats.currentStreak} days',
            color: AppColors.eatingActive,
          ),
          StatTile(
            icon: Icons.emoji_events_outlined,
            label: 'Longest Streak',
            value: '${stats.longestStreak} days',
            color: Colors.amber,
          ),
          StatTile(
            icon: Icons.timer_outlined,
            label: 'Avg Duration',
            value: Duration(minutes: stats.averageDurationMinutes.round()).toReadable,
            color: theme.colorScheme.primary,
          ),
          StatTile(
            icon: Icons.hourglass_empty,
            label: 'Total Fasted',
            value: '${stats.totalFastingHours.toStringAsFixed(1)}h',
            color: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCard(BuildContext context, StatsData stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            AnimatedProgressRing(
              progress: stats.completionRate / 100,
              size: 90,
              strokeWidth: 8,
              color: AppColors.success,
              child: Text(
                '${stats.completionRate.toStringAsFixed(0)}%',
                style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Success Rate',
                    style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'You have completed ${stats.totalCompleted} out of ${stats.totalSessions} started fasting sessions.',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurface.withValues(alpha: 0.6),
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
    final hasData = stats.weeklyData.any((v) => v > 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
                        getTooltipColor: (_) => context.colorScheme.primaryContainer,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.toStringAsFixed(1)}h',
                            TextStyle(
                              color: context.colorScheme.onPrimaryContainer,
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
                                child: Text(days[idx]),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(7, (index) {
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: stats.weeklyData[index],
                            color: context.colorScheme.primary,
                            width: 16,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                )
              : Center(
                  child: Text(
                    'No weekly data recorded yet.',
                    style: TextStyle(color: context.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMonthlyChart(BuildContext context, StatsData stats) {
    final hasData = stats.monthlyData.any((v) => v > 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
                        color: context.colorScheme.primary,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: context.colorScheme.primary.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Text(
                    'No trend data recorded yet.',
                    style: TextStyle(color: context.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ),
        ),
      ),
    );
  }
}
