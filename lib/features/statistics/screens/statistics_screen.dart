import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_animations.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/duration_extensions.dart';
import '../providers/statistics_provider.dart';
import '../../../shared/widgets/animated_progress_ring.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/shimmer_loading.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statisticsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (stats.totalSessions == 0) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
        ),
        body: const EmptyState(
          icon: Icons.analytics_outlined,
          title: 'Analytics Empty',
          subtitle: 'Complete your first fast to display analytics graphs.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(statisticsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatsGrid(context, stats, theme),
              const SectionHeader(title: 'Completion Rate'),
              _buildCompletionCard(context, stats),
              const SectionHeader(title: 'This Week'),
              _buildWeeklyChart(context, stats),
              const SectionHeader(title: 'Monthly Trend'),
              _buildMonthlyChart(context, stats),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, StatsData stats, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.35,
        children: [
          StatCard(
            icon: Icons.local_fire_department_rounded,
            label: 'Current Streak',
            value: '${stats.currentStreak} days',
            color: context.colors.eatingActive,
          ),
          StatCard(
            icon: Icons.emoji_events_rounded,
            label: 'Longest Streak',
            value: '${stats.longestStreak} days',
            color: context.colors.warning,
          ),
          StatCard(
            icon: Icons.timer_outlined,
            label: 'Avg Duration',
            value: Duration(minutes: stats.averageDurationMinutes.round()).toReadable,
            color: theme.colorScheme.primary,
          ),
          StatCard(
            icon: Icons.hourglass_empty_rounded,
            label: 'Total Fasted',
            value: '${stats.totalFastingHours.toStringAsFixed(1)}h',
            color: context.colors.success,
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
