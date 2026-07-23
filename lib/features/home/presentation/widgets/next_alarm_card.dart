import 'package:flutter/material.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_state.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';

class NextAlarmCard extends StatelessWidget {
  final FastingState timerState;

  const NextAlarmCard({required this.timerState, super.key});

  @override
  Widget build(BuildContext context) {
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
                  'Active Plan',
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
}
