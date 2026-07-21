import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';

class AverageFastDetailScreen extends ConsumerWidget {
  const AverageFastDetailScreen({super.key});

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '-';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (minutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(fastingRecordsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Average Fast Details'),
        centerTitle: true,
      ),
      body: recordsAsync.when(
        data: (records) {
          final completed = records.where((r) => r.status == 'completed').toList();
          final totalCompleted = completed.length;

          Duration totalDuration = Duration.zero;
          Duration? shortestDuration;
          Duration? longestDuration;

          for (final r in completed) {
            final duration = r.actualDuration;
            totalDuration += duration;

            if (shortestDuration == null || duration < shortestDuration) {
              shortestDuration = duration;
            }
            if (longestDuration == null || duration > longestDuration) {
              longestDuration = duration;
            }
          }

          final avgDuration = totalCompleted > 0
              ? Duration(minutes: (totalDuration.inMinutes / totalCompleted).round())
              : Duration.zero;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Highlight Average Card
                AppCard.elevated(
                  child: Column(
                    children: [
                      Text(
                        'Average Fasting Duration',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _formatDuration(avgDuration),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Based on $totalCompleted completed sessions',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                Text(
                  'Detailed Statistics',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                AppCard.elevated(
                  child: Column(
                    children: [
                      _buildStatDetailRow(
                        context,
                        label: 'Total Completed Fasts',
                        value: '$totalCompleted',
                        color: colorScheme.onSurface,
                      ),
                      const Divider(height: AppSpacing.md),
                      _buildStatDetailRow(
                        context,
                        label: 'Shortest Completed Fast',
                        value: _formatDuration(shortestDuration ?? Duration.zero),
                        color: Colors.redAccent,
                      ),
                      const Divider(height: AppSpacing.md),
                      _buildStatDetailRow(
                        context,
                        label: 'Longest Completed Fast',
                        value: _formatDuration(longestDuration ?? Duration.zero),
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading history: $err')),
      ),
    );
  }

  Widget _buildStatDetailRow(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium,
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
