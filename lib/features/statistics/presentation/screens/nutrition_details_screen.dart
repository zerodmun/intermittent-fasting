import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';

class NutritionDetailsScreen extends ConsumerStatefulWidget {
  const NutritionDetailsScreen({super.key});

  @override
  ConsumerState<NutritionDetailsScreen> createState() => _NutritionDetailsScreenState();
}

class _NutritionDetailsScreenState extends ConsumerState<NutritionDetailsScreen> {
  late String _selectedActivity;
  late String _selectedGoal;

  final List<String> _activityLevels = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Very Active',
    'Extra Active'
  ];

  final List<String> _goals = [
    'Lose Weight',
    'Maintain Weight',
    'Gain Weight'
  ];

  @override
  void initState() {
    super.initState();
    _selectedActivity = HiveService.instance.getSetting<String>('pref_activity_level') ?? 'Lightly Active';
    
    // Deduce default goal from user profile if not saved
    final profile = HiveService.instance.userProfile;
    String defaultGoal = 'Maintain Weight';
    if (profile != null) {
      if (profile.goalWeightKg < profile.weightKg) {
        defaultGoal = 'Lose Weight';
      } else if (profile.goalWeightKg > profile.weightKg) {
        defaultGoal = 'Gain Weight';
      }
    }
    _selectedGoal = HiveService.instance.getSetting<String>('pref_weight_goal') ?? defaultGoal;
  }

  double _getActivityMultiplier(String activity) {
    switch (activity) {
      case 'Sedentary': return 1.2;
      case 'Lightly Active': return 1.375;
      case 'Moderately Active': return 1.55;
      case 'Very Active': return 1.725;
      case 'Extra Active': return 1.9;
      default: return 1.375;
    }
  }

  double _getGoalAdjustment(String goal) {
    switch (goal) {
      case 'Lose Weight': return -500.0;
      case 'Gain Weight': return 500.0;
      default: return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Details'),
        centerTitle: true,
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Please complete profile setup first.'));
          }

          // 1. Calculate BMR (Mifflin-St Jeor)
          final isMale = profile.gender.toLowerCase() == 'male';
          final bmr = isMale
              ? 10.0 * profile.weightKg + 6.25 * profile.heightCm - 5.0 * profile.ageYears + 5.0
              : 10.0 * profile.weightKg + 6.25 * profile.heightCm - 5.0 * profile.ageYears - 161.0;

          // 2. Calculate TDEE and target calories
          final multiplier = _getActivityMultiplier(_selectedActivity);
          final tdee = bmr * multiplier;
          final adjustment = _getGoalAdjustment(_selectedGoal);
          final dailyCalories = (tdee + adjustment).clamp(1200.0, 5000.0).roundToDouble();

          // 3. Calculate macronutrient goals
          final proteinG = ((dailyCalories * 0.25) / 4.0).round();
          final fatG = ((dailyCalories * 0.25) / 9.0).round();
          final carbG = ((dailyCalories * 0.50) / 4.0).round();
          final fiberG = ((dailyCalories / 1000.0) * 14.0).round();
          final waterMl = (profile.weightKg * 35.0).round();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Activity & Goal configuration
                AppCard.elevated(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configure Targets',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedActivity,
                        decoration: const InputDecoration(
                          labelText: 'Activity Level',
                          border: OutlineInputBorder(),
                        ),
                        items: _activityLevels.map((act) {
                          return DropdownMenuItem(value: act, child: Text(act));
                        }).toList(),
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() {
                              _selectedActivity = val;
                            });
                            await HiveService.instance.setSetting('pref_activity_level', val);
                            ref.invalidate(userProfileProvider);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedGoal,
                        decoration: const InputDecoration(
                          labelText: 'Weight Goal',
                          border: OutlineInputBorder(),
                        ),
                        items: _goals.map((g) {
                          return DropdownMenuItem(value: g, child: Text(g));
                        }).toList(),
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() {
                              _selectedGoal = val;
                            });
                            await HiveService.instance.setSetting('pref_weight_goal', val);
                            ref.invalidate(userProfileProvider);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                Text(
                  'Daily Nutritional Targets',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Calories Card
                _buildNutritionCard(
                  context,
                  title: 'Daily Calories',
                  value: '${dailyCalories.toInt()} kcal',
                  explanation: 'Recommended daily calorie target for your selected goal.',
                  color: colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.md),

                // Protein Card
                _buildNutritionCard(
                  context,
                  title: 'Protein',
                  value: '$proteinG g',
                  explanation: 'Supports muscle maintenance and recovery.',
                  color: Colors.redAccent,
                ),
                const SizedBox(height: AppSpacing.md),

                // Fat Card
                _buildNutritionCard(
                  context,
                  title: 'Fat',
                  value: '$fatG g',
                  explanation: 'Supports hormones and overall health.',
                  color: Colors.orangeAccent,
                ),
                const SizedBox(height: AppSpacing.md),

                // Carbohydrates Card
                _buildNutritionCard(
                  context,
                  title: 'Carbohydrates',
                  value: '$carbG g',
                  explanation: 'Primary energy source.',
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: AppSpacing.md),

                // Fiber Card
                _buildNutritionCard(
                  context,
                  title: 'Fiber',
                  value: '$fiberG g',
                  explanation: 'Supports digestion.',
                  color: Colors.teal,
                ),
                const SizedBox(height: AppSpacing.md),

                // Water Card
                _buildNutritionCard(
                  context,
                  title: 'Water Intake',
                  value: '$waterMl ml',
                  explanation: 'Recommended daily hydration.',
                  color: Colors.lightBlue,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading profile: $err')),
      ),
    );
  }

  Widget _buildNutritionCard(
    BuildContext context, {
    required String title,
    required String value,
    required String explanation,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard.elevated(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            explanation,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
