import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/features/statistics/presentation/providers/statistics_provider.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/stat_card.dart';

class AverageFastDetailScreen extends ConsumerWidget {
  const AverageFastDetailScreen({super.key});

  String _formatDuration(Duration? duration, {String fallback = '-'}) {
    if (duration == null || duration == Duration.zero) return fallback;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (minutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filter = ref.watch(statsPeriodFilterProvider);
    final periodStats = ref.watch(periodStatsProvider);
    final availableYears = ref.watch(availableYearsProvider);

    final selectedYearValue = availableYears.contains(filter.year)
        ? filter.year
        : availableYears.first;

    final periodLabel = filter.mode == StatsPeriodMode.month
        ? '${DateFormat('MMMM').format(DateTime(2000, filter.month, 1))} $selectedYearValue'
        : 'Year $selectedYearValue';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Total Fast'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. MONTH / YEAR FILTER BAR (Restyled with App Standard Form Dropdowns) ──
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<StatsPeriodMode>(
                    initialValue: filter.mode,
                    decoration: InputDecoration(
                      labelText: 'Mode',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: StatsPeriodMode.month, child: Text('Month')),
                      DropdownMenuItem(value: StatsPeriodMode.year, child: Text('Year')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(statsPeriodFilterProvider.notifier).setMode(val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (filter.mode == StatsPeriodMode.month) ...[
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int>(
                      initialValue: filter.month,
                      decoration: InputDecoration(
                        labelText: 'Month',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                      ),
                      items: List.generate(12, (i) => i + 1).map((m) {
                        final monthName = DateFormat('MMMM').format(DateTime(2000, m, 1));
                        return DropdownMenuItem(
                          value: m,
                          child: Text(monthName, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(statsPeriodFilterProvider.notifier).setMonth(val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    initialValue: selectedYearValue,
                    decoration: InputDecoration(
                      labelText: 'Year',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                    ),
                    items: availableYears.map((y) {
                      return DropdownMenuItem(value: y, child: Text('$y'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(statsPeriodFilterProvider.notifier).setYear(val);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── 2. PRIMARY HIGHLIGHT CARD: TOTAL FAST ──
            AppCard.elevated(
              child: Column(
                children: [
                  Text(
                    'Total Fast ($periodLabel)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _formatDuration(periodStats.totalFastDuration, fallback: '0h'),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Based on ${periodStats.totalFasts} completed sessions',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── 3. DETAILED METRICS (5 METRICS ONLY: Longest, Shortest, Skipped, Total Fasts) ──
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.keyboard_double_arrow_up_rounded,
                      title: 'Longest Fast',
                      value: _formatDuration(periodStats.longestFastDuration),
                      iconColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatCard(
                      icon: Icons.keyboard_double_arrow_down_rounded,
                      title: 'Shortest Fast',
                      value: _formatDuration(periodStats.shortestFastDuration),
                      iconColor: Colors.amber.shade800,
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
                      icon: Icons.remove_circle_outline_rounded,
                      title: 'Skipped',
                      value: '${periodStats.skipCount}',
                      iconColor: colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatCard(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Total Fasts',
                      value: '${periodStats.totalFasts}',
                      iconColor: colorScheme.primary,
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
}
