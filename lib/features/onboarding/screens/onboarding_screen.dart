import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_animations.dart';
import '../../../core/extensions/context_extensions.dart';
import '../providers/onboarding_provider.dart';
import '../../fasting/domain/entities/fasting_schedule.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final List<String> _stepTitles = [
    'Welcome',
    'Personal Profile',
    'Weight Goal',
    'Fasting Routine',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      _currentStep++;
      _pageController.nextPage(
        duration: AppAnimations.medium,
        curve: AppAnimations.decelerate,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _currentStep--;
      _pageController.previousPage(
        duration: AppAnimations.medium,
        curve: AppAnimations.decelerate,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    await ref.read(onboardingProvider.notifier).completeOnboarding();
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                children: [
                  Row(
                    children: List.generate(4, (index) {
                      return Expanded(
                        child: AnimatedContainer(
                          duration: AppAnimations.fast,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 6,
                          decoration: BoxDecoration(
                            color: index <= _currentStep
                                ? colorScheme.primary
                                : colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _stepTitles[_currentStep],
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentStep = idx),
                children: [
                  _buildWelcomeStep(),
                  _buildProfileStep(),
                  _buildGoalStep(),
                  _buildScheduleStep(),
                ],
              ),
            ),

            // Navigation Buttons Bottom Bar
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: AppButton.outlined(
                        label: 'Back',
                        onPressed: _prevStep,
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton.primary(
                      label: _currentStep == 3 ? 'Get Started' : 'Next',
                      onPressed: _nextStep,
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

  Widget _buildWelcomeStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.spa_rounded,
            size: 90,
            color: colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Welcome to Fomo IF',
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Track your fasting windows and calculate body composition with official health metrics fully offline.',
            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        children: [
          AppInput(
            label: 'Your Name',
            hint: 'E.g., John Doe',
            onChanged: (val) => notifier.updateProfile(name: val),
          ),
          const SizedBox(height: AppSpacing.md),
          AppInput(
            label: 'Age (years)',
            hint: '25',
            keyboardType: TextInputType.number,
            onChanged: (val) => notifier.updateProfile(ageYears: int.tryParse(val) ?? 25),
          ),
          const SizedBox(height: AppSpacing.md),
          AppInput(
            label: 'Height (cm)',
            hint: '175',
            keyboardType: TextInputType.number,
            onChanged: (val) => notifier.updateProfile(heightCm: double.tryParse(val) ?? 175.0),
          ),
          const SizedBox(height: AppSpacing.md),
          AppInput(
            label: 'Current Weight (kg)',
            hint: '70',
            keyboardType: TextInputType.number,
            onChanged: (val) => notifier.updateProfile(weightKg: double.tryParse(val) ?? 70.0),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildGenderSelector(state.gender, notifier),
        ],
      ),
    );
  }

  Widget _buildGenderSelector(String current, OnboardingNotifier notifier) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isMaleSelected = current.toLowerCase() == 'male';
    final isFemaleSelected = current.toLowerCase() == 'female';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Gender',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => notifier.updateProfile(gender: 'male'),
                child: isMaleSelected
                    ? AppCard.outlined(
                        child: Center(
                          child: Text(
                            'Male',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      )
                    : AppCard(
                        child: Center(
                          child: Text(
                            'Male',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: GestureDetector(
                onTap: () => notifier.updateProfile(gender: 'female'),
                child: isFemaleSelected
                    ? AppCard.outlined(
                        child: Center(
                          child: Text(
                            'Female',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      )
                    : AppCard(
                        child: Center(
                          child: Text(
                            'Female',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGoalStep() {
    final notifier = ref.read(onboardingProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        children: [
          AppInput(
            label: 'Goal Weight (kg)',
            hint: '65',
            keyboardType: TextInputType.number,
            onChanged: (val) => notifier.updateProfile(goalWeightKg: double.tryParse(val) ?? 65.0),
          ),
          const SizedBox(height: AppSpacing.md),
          AppInput(
            label: 'Target Waist (cm - optional)',
            hint: '80',
            keyboardType: TextInputType.number,
            onChanged: (val) => notifier.updateProfile(targetWaist: double.tryParse(val)),
          ),
          const SizedBox(height: AppSpacing.md),
          AppInput(
            label: 'Target Body Fat % (optional)',
            hint: '15',
            keyboardType: TextInputType.number,
            onChanged: (val) => notifier.updateProfile(targetBodyFat: double.tryParse(val)),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleStep() {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final theme = Theme.of(context);

    final monday = state.dailySchedules[1] ?? DailySchedule(fastHour: 17, fastMin: 0, eatHour: 9, eatMin: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Configure Fasting Routine',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'By default, we set a standard 16:8 cycle (17:00 Fasting, 09:00 Eating). You can change this per day later.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard.elevated(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.nights_stay_outlined, color: context.colors.fastingActive),
                  title: const Text('Fasting Starts (Default)'),
                  trailing: Text(
                    '${monday.fastHour.toString().padLeft(2, '0')}:${monday.fastMin.toString().padLeft(2, '0')}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: monday.fastHour, minute: monday.fastMin),
                    );
                    if (time != null) {
                      final updated = Map<int, DailySchedule>.from(state.dailySchedules);
                      updated[1] = DailySchedule(
                        fastHour: time.hour,
                        fastMin: time.minute,
                        eatHour: monday.eatHour,
                        eatMin: monday.eatMin,
                      );
                      notifier.updateSchedules(updated);
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.restaurant_rounded, color: context.colors.eatingActive),
                  title: const Text('Eating Starts (Default)'),
                  trailing: Text(
                    '${monday.eatHour.toString().padLeft(2, '0')}:${monday.eatMin.toString().padLeft(2, '0')}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: monday.eatHour, minute: monday.eatMin),
                    );
                    if (time != null) {
                      final updated = Map<int, DailySchedule>.from(state.dailySchedules);
                      updated[1] = DailySchedule(
                        fastHour: monday.fastHour,
                        fastMin: monday.fastMin,
                        eatHour: time.hour,
                        eatMin: time.minute,
                      );
                      notifier.updateSchedules(updated);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}