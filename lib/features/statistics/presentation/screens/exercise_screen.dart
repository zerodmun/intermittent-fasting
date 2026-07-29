import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/features/statistics/domain/entities/workout_log.dart';
import 'package:fast_flow/features/statistics/presentation/providers/workout_providers.dart';
import 'package:fast_flow/features/statistics/presentation/screens/workout_detail_screen.dart';
import 'package:fast_flow/features/statistics/presentation/widgets/add_edit_workout_sheet.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/app_dialog.dart';
import 'package:fast_flow/shared/widgets/section_header.dart';

/// Standalone Workout Journal & Exercises Module screen.
/// Completely decoupled from fasting, weight, or profile features.
class ExerciseScreen extends ConsumerWidget {
  const ExerciseScreen({super.key});

  void _showAddWorkoutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AddEditWorkoutSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final workoutLogs = ref.watch(workoutLogsProvider);
    final stats = ref.watch(workoutStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercises Log'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TextButton.icon(
              onPressed: () => _showAddWorkoutSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Workout', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: workoutLogs.isEmpty
          ? _buildEmptyState(context, theme, colorScheme)
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.md,
              ),
              children: [
                // Standalone Workout Statistics Summary Header
                const SectionHeader(title: 'Workout Statistics'),
                AppCard.elevated(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                              title: 'Workouts',
                              value: '${stats['totalWorkouts']}',
                              icon: Icons.fitness_center_rounded,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _StatBox(
                              title: 'Exercises',
                              value: '${stats['totalExercises']}',
                              icon: Icons.list_alt_rounded,
                              color: colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _StatBox(
                              title: 'Total Sets',
                              value: '${stats['totalSets']}',
                              icon: Icons.repeat_rounded,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                              title: 'Total Volume',
                              value: '${(stats['totalVolumeKg'] as double).toStringAsFixed(0)} kg',
                              icon: Icons.monitor_weight_outlined,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _StatBox(
                              title: 'Total Duration',
                              value: '${stats['totalDurationMinutes'] ?? 0} min',
                              icon: Icons.timer_rounded,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _StatBox(
                              title: 'Est. Calories',
                              value: '${(stats['totalCaloriesBurned'] as double).toStringAsFixed(0)} kcal',
                              icon: Icons.local_fire_department_rounded,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Workout Journal History List
                SectionHeader(title: 'Workout Journal (${workoutLogs.length})'),
                ...workoutLogs.map((log) => _buildWorkoutCard(context, ref, theme, colorScheme, log)),
                const SizedBox(height: AppSpacing.xxl * 2),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fitness_center_rounded,
                size: 52,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Workouts Logged Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Track your strength training sessions, exercises, sets, reps, volume, and estimated calorie burn in your standalone workout journal.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => _showAddWorkoutSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Log Your First Workout', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme colorScheme,
    WorkoutLog log,
  ) {
    final formattedDate = '${log.date.day}/${log.date.month}/${log.date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard.elevated(
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkoutDetailScreen(workout: log),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      log.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      formattedDate,
                      style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) async {
                      if (val == 'edit') {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (context) => AddEditWorkoutSheet(existingLog: log),
                        );
                      } else if (val == 'delete') {
                        final confirm = await AppDialog.showConfirm(
                          context: context,
                          title: 'Delete Workout',
                          content: 'Are you sure you want to delete "${log.title}"?',
                          isDestructive: true,
                        );
                        if (confirm == true) {
                          ref.read(workoutLogsProvider.notifier).deleteWorkoutLog(log.id);
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(Icons.fitness_center_rounded, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${log.totalExercises} Exercises (${log.totalSets} sets)',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.timer_rounded, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${log.durationMinutes} min',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Volume',
                        style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        '${log.totalVolumeKg.toStringAsFixed(0)} kg',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Est. Calories Burned',
                        style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        '~${log.estimatedCaloriesBurned.toStringAsFixed(0)} kcal',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
