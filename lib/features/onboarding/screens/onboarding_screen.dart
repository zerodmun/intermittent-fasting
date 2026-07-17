import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fast_flow/features/onboarding/providers/onboarding_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => notifier.setPage(page),
                  children: [
                    _buildWelcomePage(),
                    _buildGoalPage(state, notifier),
                    _buildProfilePage(state, notifier),
                    _buildPlanPage(state, notifier),
                  ],
                ),
              ),
              _buildBottomControls(state, notifier),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/illustrations/welcome.svg',
            height: 160,
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Text(
            'Welcome to FastFlow',
            style: context.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Your personal intermittent fasting companion. Track fasts, monitor weight, view statistics, and build healthy habits.',
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalPage(OnboardingState state, OnboardingNotifier notifier) {
    final goals = [
      _GoalItem('Lose Weight', 'Reduce body fat and manage calorie intake.', Icons.monitor_weight_outlined),
      _GoalItem('Improve Health', 'Enhance cellular repair (autophagy) and insulin sensitivity.', Icons.favorite_outline_rounded),
      _GoalItem('Build Discipline', 'Develop conscious eating patterns and control cravings.', Icons.psychology_outlined),
    ];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/illustrations/benefits.svg',
            height: 120,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'What\'s your goal?',
            style: context.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          ...goals.map((g) {
            final isSelected = state.goal == g.title;
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                side: BorderSide(
                  color: isSelected ? context.colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              color: isSelected
                  ? context.colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : context.colorScheme.surfaceContainerLow,
              child: ListTile(
                onTap: () => notifier.setGoal(g.title),
                leading: Icon(g.icon, color: isSelected ? context.colorScheme.primary : null),
                title: Text(g.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(g.desc),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProfilePage(OnboardingState state, OnboardingNotifier notifier) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SvgPicture.asset(
            'assets/illustrations/weight_goal.svg',
            height: 120,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Tell us about yourself',
            style: context.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Enter your name',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
            onChanged: (value) => notifier.setName(value),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Gender', style: context.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Male', label: Text('Male')),
              ButtonSegment(value: 'Female', label: Text('Female')),
              ButtonSegment(value: 'Other', label: Text('Other')),
            ],
            selected: {state.gender},
            onSelectionChanged: (set) => notifier.setGender(set.first),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Height', style: context.textTheme.titleSmall),
              Text('${state.heightCm.round()} cm', style: context.textTheme.titleSmall?.copyWith(color: context.colorScheme.primary)),
            ],
          ),
          Slider(
            min: 100,
            max: 250,
            value: state.heightCm,
            onChanged: (value) => notifier.setHeight(value),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Current Weight', style: context.textTheme.titleSmall),
              Text('${state.weightKg.toStringAsFixed(1)} kg', style: context.textTheme.titleSmall?.copyWith(color: context.colorScheme.primary)),
            ],
          ),
          Slider(
            min: 30,
            max: 200,
            value: state.weightKg,
            onChanged: (value) => notifier.setWeight(value),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Goal Weight', style: context.textTheme.titleSmall),
              Text('${state.goalWeightKg.toStringAsFixed(1)} kg', style: context.textTheme.titleSmall?.copyWith(color: context.colorScheme.primary)),
            ],
          ),
          Slider(
            min: 30,
            max: 200,
            value: state.goalWeightKg,
            onChanged: (value) => notifier.setGoalWeight(value),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanPage(OnboardingState state, OnboardingNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/illustrations/fasting_intro.svg',
            height: 140,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Daily Fasting Schedule',
            style: context.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your schedule is set to repeat every day:\n\n• Fasting starts: 17:00\n• Eating starts: 09:00\n\nNo preset plan choices required! You can customize this schedule day-by-day in the app settings anytime.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(OnboardingState state, OnboardingNotifier notifier) {
    final isLastPage = state.currentPage == 3;
    final isFirstPage = state.currentPage == 0;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          Opacity(
            opacity: isFirstPage ? 0.0 : 1.0,
            child: TextButton(
              onPressed: isFirstPage
                  ? null
                  : () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                      );
                    },
              child: const Text('Back'),
            ),
          ),

          // Dots indicator
          Row(
            children: List.generate(4, (index) {
              final isCurrent = state.currentPage == index;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: isCurrent ? 24 : 8,
                decoration: BoxDecoration(
                  color: isCurrent ? context.colorScheme.primary : context.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          // Next / Complete button
          FilledButton(
            onPressed: () async {
              if (state.currentPage == 2) {
                // Validate form name on page 2
                if (!_formKey.currentState!.validate()) return;
              }

              if (isLastPage) {
                await notifier.completeOnboarding();
                if (mounted) {
                  context.go('/home');
                }
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: Text(isLastPage ? 'Get Started' : 'Next'),
          ),
        ],
      ),
    );
  }
}

class _GoalItem {
  final String title;
  final String desc;
  final IconData icon;
  _GoalItem(this.title, this.desc, this.icon);
}
