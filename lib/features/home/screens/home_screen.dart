import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fast_flow/core/constants/app_colors.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/core/extensions/duration_extensions.dart';
import 'package:fast_flow/features/fasting/models/fasting_record.dart';
import 'package:fast_flow/features/fasting/providers/fasting_provider.dart';
import 'package:fast_flow/features/home/providers/home_provider.dart';
import 'package:fast_flow/shared/widgets/animated_progress_ring.dart';
import 'package:fast_flow/shared/widgets/empty_state.dart';
import 'package:fast_flow/shared/widgets/gradient_card.dart';
import 'package:fast_flow/shared/widgets/section_header.dart';
import 'package:fast_flow/shared/widgets/stat_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-watch general providers to trigger builds when data updates
    final profile = ref.watch(userProfileProvider);
    final timerState = ref.watch(fastingStateProvider2);
    final streak = ref.watch(streakProvider);
    final records = ref.watch(fastingRecordsProvider);
    final weights = ref.watch(weightEntriesProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, profile),
              _buildFastingStatusCard(context, timerState),
              const SectionHeader(title: 'Today\'s Summary'),
              _buildStatsGrid(context, streak, timerState, records),
              SectionHeader(
                title: 'Weight Tracker',
                actionLabel: 'Track',
                onAction: () => context.go('/home/weight'),
              ),
              _buildWeightCard(context, profile, weights),
              const SectionHeader(title: 'Recent Fasts'),
              _buildRecentFastsList(context, records),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic profile) {
    final now = DateTime.now();
    final name = profile?.name ?? 'Faster';
    String greeting;

    if (now.hour < 12) {
      greeting = 'Good morning';
    } else if (now.hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                name,
                style: context.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          CircleAvatar(
            radius: 24,
            backgroundColor: context.colorScheme.primary.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'F',
              style: TextStyle(
                color: context.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFastingStatusCard(BuildContext context, FastingState? timerState) {
    if (timerState == null) {
      return const SizedBox.shrink();
    }
    final isFasting = timerState.currentPhase == FastingPhase.fasting;
    final status = timerState.status;

    final gradient = isFasting ? AppColors.fastingGradient : AppColors.eatingGradient;

    String title = 'Fasting Active';
    String subtitle = 'Keep it up! Autophagy is working.';

    if (status == FastingStatus.eatingWindow) {
      title = 'Eating Window';
      subtitle = 'Enjoy your meals mindfully!';
    } else if (status == FastingStatus.preparing) {
      title = 'Preparing to Fast';
      subtitle = 'Fasting period is starting soon.';
    } else if (status == FastingStatus.completed) {
      title = 'Fasting Completed';
      subtitle = 'Excellent job on completing today\'s fast!';
    } else if (status == FastingStatus.skipped) {
      title = 'Fasting Skipped';
      subtitle = 'Fasting is skipped for today.';
    } else if (status == FastingStatus.cancelled) {
      title = 'Fasting Cancelled';
      subtitle = 'Fasting was cancelled for today.';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: GradientCard(
        gradient: gradient,
        onTap: () => context.go('/home/fasting'),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: () => context.go('/home/fasting'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isFasting ? AppColors.fastingActive : AppColors.eatingActive,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                      ),
                    ),
                    child: const Text('View Timer'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            AnimatedProgressRing(
              progress: timerState.progress,
              size: 80,
              strokeWidth: 6,
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              child: Text(
                timerState.remaining.toHHMM,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    dynamic streak,
    FastingState? timerState,
    List<FastingRecord> records,
  ) {
    final completedCount = records.where((r) => r.status == 'completed').length;
    final todaySched = timerState?.schedule.getScheduleFor(DateTime.now().weekday);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.9,
        children: [
          StatTile(
            icon: Icons.local_fire_department,
            label: 'Day Streak',
            value: '${streak.currentStreak}',
            color: AppColors.eatingActive,
          ),
          StatTile(
            icon: Icons.schedule,
            label: 'Plan',
            value: todaySched != null
                ? '${todaySched['fastHour']}:${todaySched['fastMin'].toString().padLeft(2, '0')}'
                : '--:--',
            color: context.colorScheme.primary,
          ),
          StatTile(
            icon: Icons.check_circle_outline,
            label: 'Completed',
            value: '$completedCount',
            color: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildWeightCard(BuildContext context, dynamic profile, List<dynamic> weights) {
    if (weights.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Text(
                'No weight logged yet',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => context.go('/home/weight'),
                icon: const Icon(Icons.add),
                label: const Text('Log Initial Weight'),
              ),
            ],
          ),
        ),
      );
    }

    final latestWeight = weights.first.weightKg;
    final goalWeight = profile?.goalWeightKg ?? 70.0;
    final diff = (latestWeight - goalWeight).abs();
    final direction = latestWeight > goalWeight ? 'above' : 'below';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current',
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      '${latestWeight.toStringAsFixed(1)} kg',
                      style: context.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Goal',
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      '${goalWeight.toStringAsFixed(1)} kg',
                      style: context.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(
              value: 0.6, // placeholder weight progress ratio
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${diff.toStringAsFixed(1)} kg $direction goal weight',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentFastsList(BuildContext context, List<FastingRecord> records) {
    if (records.isEmpty) {
      return const EmptyState(
        icon: Icons.history_toggle_off,
        title: 'No fasts recorded',
        subtitle: 'Start fasting to log your first record!',
        illustrationPath: 'assets/illustrations/empty_history.svg',
      );
    }

    final recent = records.take(3).toList();

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recent.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final record = recent[index];
          final isCompleted = record.status == 'completed';

          return ListTile(
            leading: Icon(
              isCompleted ? Icons.check_circle : Icons.cancel_outlined,
              color: isCompleted ? AppColors.success : context.colorScheme.error,
            ),
            title: Text(record.planName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${DateFormat('MMM d').format(record.startTime)} • ${record.actualDuration.toReadable}',
            ),
            trailing: Text(
              record.status.toUpperCase(),
              style: context.textTheme.labelSmall?.copyWith(
                color: isCompleted ? AppColors.success : context.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }
}
