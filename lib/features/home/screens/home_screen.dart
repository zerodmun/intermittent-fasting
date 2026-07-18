import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/core/extensions/duration_extensions.dart';
import 'package:fast_flow/features/fasting/presentation/providers/fasting_providers.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_state.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';
import 'package:fast_flow/features/weight/domain/entities/weight_entry.dart';
import 'package:fast_flow/core/helpers/streak_calculator.dart';

import 'package:fast_flow/shared/widgets/animated_progress_ring.dart';
import 'package:fast_flow/shared/widgets/empty_state.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/section_header.dart';
import 'package:fast_flow/shared/widgets/stat_card.dart';
import 'package:fast_flow/shared/widgets/animated_list_item.dart';
import 'package:fast_flow/shared/widgets/shimmer_loading.dart';
import 'package:fast_flow/shared/widgets/metric_change_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final timerState = ref.watch(fastingStateNotifierProvider);
    final streak = ref.watch(streakProvider);
    final recordsAsync = ref.watch(fastingRecordsProvider);
    final weightAsync = ref.watch(weightEntriesProvider);

    return Scaffold(
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const _LoadingDashboard(),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (profile) {
            if (profile == null) {
              return const EmptyState(
                icon: Icons.person_off_rounded,
                title: 'No profile found',
                subtitle: 'Please complete the onboarding flow.',
              );
            }

            if (timerState == null) {
              return const _LoadingDashboard();
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(userProfileProvider);
                ref.invalidate(fastingRecordsProvider);
                ref.invalidate(weightEntriesProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context, profile),
                    const SizedBox(height: AppSpacing.sm),
                    _buildFastingStatusHero(context, timerState),
                    const SizedBox(height: AppSpacing.md),
                    _buildScheduleStrip(context, timerState),
                    const SizedBox(height: AppSpacing.md),
                    _buildQuickStats(context, streak, timerState),
                    const SizedBox(height: AppSpacing.md),
                    _buildBodyCompSummary(context, profile, weightAsync),
                    const SizedBox(height: AppSpacing.md),
                    _buildRecentFasts(context, recordsAsync),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final hour = now.hour;

    final String greeting;
    final IconData greetingIcon;

    if (hour < 12) {
      greeting = 'Good Morning';
      greetingIcon = Icons.light_mode_rounded;
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
      greetingIcon = Icons.wb_sunny_rounded;
    } else {
      greeting = 'Good Evening';
      greetingIcon = Icons.nightlight_round;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      greetingIcon,
                      size: AppSpacing.iconSm,
                      color: context.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      greeting,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  profile.name,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Hero(
            tag: 'avatar_hero',
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    context.colorScheme.primary,
                    context.colorScheme.tertiary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: AppSpacing.shadowSm(context.colorScheme.outline),
              ),
              child: Center(
                child: Text(
                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'F',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: context.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFastingStatusHero(BuildContext context, FastingState timerState) {
    final theme = Theme.of(context);
    final isFasting = timerState.currentPhase == FastingPhase.fasting;
    final LinearGradient cardGradient;
    String title = 'Fasting Active';
    String subtitle = 'Keep going! Your body is burning fat.';

    switch (timerState.status) {
      case FastingStatus.eatingWindow:
        title = 'Eating Window';
        subtitle = 'Enjoy healthy nutrients and fuel up.';
        cardGradient = context.colors.eatingGradient;
        break;
      case FastingStatus.preparing:
        title = 'Preparing to Fast';
        subtitle = 'Your fasting phase will start shortly.';
        cardGradient = context.colors.preparingGradient;
        break;
      case FastingStatus.completed:
        title = 'Fast Completed!';
        subtitle = 'Amazing job! You finished your scheduled fast.';
        cardGradient = context.colors.completedGradient;
        break;
      case FastingStatus.skipped:
        title = 'Fasting Skipped';
        subtitle = 'Rest day logged. Resume when ready.';
        cardGradient = LinearGradient(
          colors: [
            context.colorScheme.surfaceVariant,
            context.colorScheme.outlineVariant,
          ],
        );
        break;
      default:
        cardGradient = context.colors.fastingGradient;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: AppCard.gradient(
        gradient: cardGradient,
        onTap: () => context.go('/home/fasting'),
        child: Stack(
          children: [
            // Decorative subtle background bubble
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Text(
                          title,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: AppSpacing.iconSm,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isFasting ? 'Fasting Time Remaining' : 'Eating Window Remaining',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                AnimatedProgressRing(
                  progress: timerState.progress,
                  size: 110,
                  strokeWidth: 8,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        timerState.remaining.toHHMM,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'left',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleStrip(BuildContext context, FastingState timerState) {
    final theme = Theme.of(context);
    final activeWeekday = timerState.activeWindowStart.weekday;
    final activeSched = timerState.schedule.getScheduleFor(activeWeekday);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: AppCard.outlined(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: AppSpacing.iconMd,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  "Active Plan",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            Text(
              'Fasting: ${activeSched.fastTimeFormatted}  •  Eating: ${activeSched.eatTimeFormatted}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(
    BuildContext context,
    StreakResult streak,
    FastingState timerState,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.85,
        children: [
          StatCard(
            icon: Icons.local_fire_department_rounded,
            label: 'Day Streak',
            value: '${streak.currentStreak}',
            color: context.colors.eatingActive,
          ),
          StatCard(
            icon: Icons.lock_clock,
            label: 'Completed',
            value: '${streak.totalCompleted}',
            color: context.colors.completedActive,
          ),
          StatCard(
            icon: Icons.insights_rounded,
            label: 'Consistency',
            value: streak.totalCompleted > 0
                ? '${((streak.currentStreak / streak.totalCompleted.clamp(1, 100)) * 100).toInt()}%'
                : '0%',
            color: context.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildBodyCompSummary(
    BuildContext context,
    UserProfile profile,
    AsyncValue<List<WeightEntry>> weightAsync,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Body Composition',
          actionLabel: 'Details',
          onAction: () => context.go('/home/weight'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: weightAsync.when(
            loading: () => const ShimmerLoading(width: double.infinity, height: 130),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (entries) {
              if (entries.isEmpty) {
                return AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        Icon(
                          Icons.scale_rounded,
                          size: 40,
                          color: context.colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'No body measurements logged yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: () => context.go('/home/weight'),
                          child: const Text('Add Weight Entry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final latest = entries.first;
              final previous = entries.length > 1 ? entries[1] : null;
              final weightChange = previous != null ? latest.weightKg - previous.weightKg : 0.0;

              return AppCard.elevated(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weight',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '${latest.weightKg.toStringAsFixed(1)} kg',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: context.colorScheme.onSurface,
                                  ),
                                ),
                                if (previous != null) ...[
                                  const SizedBox(width: 8),
                                  MetricChangeBadge(
                                    change: weightChange,
                                    unit: 'kg',
                                    isDecreaseSuccess: true,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Target Weight',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${profile.goalWeightKg.toStringAsFixed(1)} kg',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: context.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: LinearProgressIndicator(
                        value: _calculateWeightProgress(
                          latest.weightKg,
                          profile.weightKg, // Starting weight
                          profile.goalWeightKg,
                        ),
                        minHeight: 8,
                        backgroundColor: context.colorScheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(context.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Starting: ${profile.weightKg.toStringAsFixed(1)} kg',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          latest.weightKg > profile.goalWeightKg
                              ? '${(latest.weightKg - profile.goalWeightKg).toStringAsFixed(1)} kg above goal'
                              : 'Goal Achieved!',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: latest.weightKg > profile.goalWeightKg
                                ? context.colorScheme.primary
                                : context.colors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  double _calculateWeightProgress(double current, double start, double goal) {
    if (start == goal) return 1.0;
    final total = start - goal;
    final done = start - current;
    if (total == 0) return 0.0;
    return (done / total).clamp(0.0, 1.0);
  }

  Widget _buildRecentFasts(
    BuildContext context,
    AsyncValue<List<FastingRecord>> recordsAsync,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Recent History',
          actionLabel: 'View Full History',
          onAction: () => context.push('/home/history'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: recordsAsync.when(
            loading: () => Column(
              children: List.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ShimmerLoading(width: double.infinity, height: 72),
                ),
              ),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (records) {
              if (records.isEmpty) {
                return const EmptyState(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'No logged fasts yet',
                  subtitle: 'Completed cycles will appear here.',
                );
              }

              final recent = records.take(3).toList();

              return AppCard.outlined(
                padding: EdgeInsets.zero,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recent.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final record = recent[index];
                    final isCompleted = record.status == 'completed';

                    return AnimatedListItem(
                      index: index,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? context.colors.success.withValues(alpha: 0.1)
                                : context.colorScheme.error.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCompleted ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                            color: isCompleted ? context.colors.success : context.colorScheme.error,
                            size: AppSpacing.iconMd,
                          ),
                        ),
                        title: Text(
                          record.planName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '${DateFormat('MMM dd, yyyy').format(record.startTime)} • ${record.actualDuration.toReadable}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? context.colors.successContainer
                                : context.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text(
                            record.status.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isCompleted
                                  ? context.colors.onSuccessContainer
                                  : context.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LoadingDashboard extends StatelessWidget {
  const _LoadingDashboard();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerLoading(width: 140, height: 20),
                  SizedBox(height: 6),
                  ShimmerLoading(width: 200, height: 32),
                ],
              ),
              const ShimmerLoading(width: 52, height: 52, borderRadius: 26),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const ShimmerLoading(width: double.infinity, height: 160, borderRadius: AppSpacing.radiusLg),
          const SizedBox(height: AppSpacing.md),
          const ShimmerLoading(width: double.infinity, height: 48, borderRadius: AppSpacing.radiusMd),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: const [
              Expanded(child: ShimmerLoading(width: double.infinity, height: 100)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: ShimmerLoading(width: double.infinity, height: 100)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: ShimmerLoading(width: double.infinity, height: 100)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const ShimmerLoading(width: 120, height: 24),
          const SizedBox(height: AppSpacing.sm),
          const ShimmerLoading(width: double.infinity, height: 120, borderRadius: AppSpacing.radiusLg),
        ],
      ),
    );
  }
}