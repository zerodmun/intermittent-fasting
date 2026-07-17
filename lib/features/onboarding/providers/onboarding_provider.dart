import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/features/onboarding/models/user_profile.dart';
import 'package:fast_flow/features/weight/models/weight_entry.dart';

class OnboardingState {
  final int currentPage;
  final String name;
  final String gender;
  final double heightCm;
  final double weightKg;
  final double goalWeightKg;
  final String selectedPlanId;
  final String goal;

  const OnboardingState({
    this.currentPage = 0,
    this.name = '',
    this.gender = 'Male',
    this.heightCm = 170.0,
    this.weightKg = 70.0,
    this.goalWeightKg = 65.0,
    this.selectedPlanId = '16_8',
    this.goal = 'Lose Weight',
  });

  OnboardingState copyWith({
    int? currentPage,
    String? name,
    String? gender,
    double? heightCm,
    double? weightKg,
    double? goalWeightKg,
    String? selectedPlanId,
    String? goal,
  }) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goalWeightKg: goalWeightKg ?? this.goalWeightKg,
      selectedPlanId: selectedPlanId ?? this.selectedPlanId,
      goal: goal ?? this.goal,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    return const OnboardingState();
  }

  void setPage(int page) {
    state = state.copyWith(currentPage: page);
  }

  void setName(String name) {
    state = state.copyWith(name: name);
  }

  void setGender(String gender) {
    state = state.copyWith(gender: gender);
  }

  void setHeight(double height) {
    state = state.copyWith(heightCm: height);
  }

  void setWeight(double weight) {
    state = state.copyWith(weightKg: weight);
  }

  void setGoalWeight(double weight) {
    state = state.copyWith(goalWeightKg: weight);
  }

  void setPlan(String planId) {
    state = state.copyWith(selectedPlanId: planId);
  }

  void setGoal(String goal) {
    state = state.copyWith(goal: goal);
  }

  Future<void> completeOnboarding() async {
    final profile = UserProfile(
      name: state.name.trim().isEmpty ? 'Faster' : state.name.trim(),
      gender: state.gender,
      heightCm: state.heightCm,
      weightKg: state.weightKg,
      goalWeightKg: state.goalWeightKg,
      selectedPlanId: state.selectedPlanId,
      onboardingComplete: true,
    );

    // Save profile to Hive
    await HiveService.instance.saveUserProfile(profile);

    // Save initial weight entry
    final weightEntry = WeightEntry(
      id: const Uuid().v4(),
      weightKg: state.weightKg,
      date: DateTime.now(),
      note: 'Initial weight recorded during onboarding',
    );
    await HiveService.instance.saveWeightEntry(weightEntry);

    // Save onboarding completion flag in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, OnboardingState>(OnboardingNotifier.new);
