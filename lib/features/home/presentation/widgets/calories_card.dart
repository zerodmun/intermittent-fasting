import 'package:flutter/material.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_state.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';
import 'package:fast_flow/shared/widgets/stat_card.dart';

class CaloriesCard extends StatelessWidget {
  final UserProfile profile;
  final FastingState timerState;

  const CaloriesCard({
    required this.profile,
    required this.timerState,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isMale = profile.gender.toLowerCase() == 'male' || profile.gender.toLowerCase() == 'm';
    final bmr = (10 * profile.weightKg) + (6.25 * profile.heightCm) - (5 * profile.ageYears) + (isMale ? 5 : -161);

    final isFasting = timerState.currentPhase == FastingPhase.fasting;
    int estimatedCalories = 0;
    if (isFasting) {
      final currentFastingMinutes = timerState.elapsed.inSeconds / 60.0;
      final caloriesPerMinute = bmr / 1440.0;
      estimatedCalories = (caloriesPerMinute * currentFastingMinutes).round();
    }

    return StatCard(
      icon: Icons.local_fire_department_rounded,
      title: 'Burned Calories',
      value: '🔥 $estimatedCalories kcal',
      iconColor: context.colors.eatingActive,
      infoButton: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showCaloriesInfoDialog(context, profile, bmr),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  void _showCaloriesInfoDialog(BuildContext context, UserProfile profile, double bmr) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: colorScheme.primary, size: AppSpacing.iconLg),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Calorie Burn Estimate',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'The Calories Burned value is an estimate of energy expenditure during your current fasting session. It is not a direct medical measurement.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Basal Metabolic Rate (BMR)',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Calculated using the Mifflin-St Jeor Equation:',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '• Gender: ${profile.gender}\n'
                        '• Age: ${profile.ageYears} years\n'
                        '• Height: ${profile.heightCm.round()} cm\n'
                        '• Weight: ${profile.weightKg.round()} kg\n'
                        '• Estimated BMR: ${bmr.round()} kcal/day',
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'How it is calculated:',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '1. BMR is divided by 1440 to estimate calories burned per minute.\n'
                  '2. This rate is multiplied by the current fasting session duration (in minutes).\n'
                  '3. Active physical activity is not factored into this baseline calculation.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
