import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/core/extensions/duration_extensions.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_state.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/animated_progress_ring.dart';

class FastingProgressCard extends StatelessWidget {
  final FastingState timerState;

  const FastingProgressCard({required this.timerState, super.key});

  @override
  Widget build(BuildContext context) {
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
            context.colorScheme.surfaceContainerHighest,
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
}
