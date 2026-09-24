import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/logger_service.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';

class OnboardingState {
  final int currentStep;
  final String name;
  final String gender;
  final int ageYears;
  final double heightCm;
  final double weightKg;
  final double goalWeightKg;
  final double targetBodyFat;
  final double targetWaist;
  final double targetBmi;
  final Map<int, DailySchedule> dailySchedules;

  OnboardingState({
    this.currentStep = 0,
    this.name = '',
    this.gender = 'male',
    this.ageYears = 25,
    this.heightCm = 170,
    this.weightKg = 70,
    this.goalWeightKg = 65,
    this.targetBodyFat = 15,
    this.targetWaist = 80,
    this.targetBmi = 22,
    Map<int, DailySchedule>? dailySchedules,
  }) : dailySchedules = dailySchedules ?? _defaultSchedules();

  static Map<int, DailySchedule> _defaultSchedules() {
    final schedules = <int, DailySchedule>{};
    for (int day = 1; day <= 7; day++) {
      schedules[day] = DailySchedule(
        fastHour: 20,
        fastMin: 0,
        eatHour: 12,
        eatMin: 0,
      );
    }
    return schedules;
  }

  OnboardingState copyWith({
    int? currentStep,
    String? name,
    String? gender,
    int? ageYears,
    double? heightCm,
    double? weightKg,
    double? goalWeightKg,
    double? targetBodyFat,
    double? targetWaist,
    double? targetBmi,
    Map<int, DailySchedule>? dailySchedules,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      ageYears: ageYears ?? this.ageYears,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goalWeightKg: goalWeightKg ?? this.goalWeightKg,
      targetBodyFat: targetBodyFat ?? this.targetBodyFat,
      targetWaist: targetWaist ?? this.targetWaist,
      targetBmi: targetBmi ?? this.targetBmi,
      dailySchedules: dailySchedules ?? this.dailySchedules,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    final existing = HiveService.instance.userProfile;
    if (existing != null) {
      return OnboardingState(
        name: existing.name,
        gender: existing.gender.isNotEmpty ? existing.gender : 'male',
        ageYears: existing.ageYears > 0 ? existing.ageYears : 25,
        heightCm: existing.heightCm > 0 ? existing.heightCm : 170.0,
        weightKg: existing.weightKg > 0 ? existing.weightKg : 70.0,
        goalWeightKg: existing.goalWeightKg > 0 ? existing.goalWeightKg : 65.0,
        targetBodyFat: existing.targetBodyFat > 0 ? existing.targetBodyFat : 15.0,
        targetWaist: existing.targetWaist > 0 ? existing.targetWaist : 80.0,
        targetBmi: existing.targetBmi > 0 ? existing.targetBmi : 22.0,
      );
    }
    return OnboardingState();
  }

  void nextStep() => state = state.copyWith(currentStep: state.currentStep + 1);
  void prevStep() => state = state.copyWith(currentStep: state.currentStep - 1);

  void updateProfile({
    String? name,
    String? gender,
    int? ageYears,
    double? heightCm,
    double? weightKg,
    double? goalWeightKg,
    double? targetBodyFat,
    double? targetWaist,
    double? targetBmi,
  }) {
    state = state.copyWith(
      name: name ?? state.name,
      gender: gender ?? state.gender,
      ageYears: ageYears ?? state.ageYears,
      heightCm: heightCm ?? state.heightCm,
      weightKg: weightKg ?? state.weightKg,
      goalWeightKg: goalWeightKg ?? state.goalWeightKg,
      targetBodyFat: targetBodyFat ?? state.targetBodyFat,
      targetWaist: targetWaist ?? state.targetWaist,
      targetBmi: targetBmi ?? state.targetBmi,
    );
  }

  void updateSchedules(Map<int, DailySchedule> schedules) {
    state = state.copyWith(dailySchedules: schedules);
  }

  Future<void> completeOnboarding() async {
    final profile = UserProfile(
      name: state.name,
      gender: state.gender,
      ageYears: state.ageYears,
      heightCm: state.heightCm,
      weightKg: state.weightKg,
      goalWeightKg: state.goalWeightKg,
      targetBodyFat: state.targetBodyFat,
      targetWaist: state.targetWaist,
      targetBmi: state.targetBmi,
      selectedPlanId: 'custom',
      onboardingComplete: true,
    );

    final schedule = FastingSchedule(dailySchedules: state.dailySchedules);

    await HiveService.instance.saveUserProfile(profile);
    await HiveService.instance.saveFastingSchedule(schedule);

    // Sync profile to Firestore if Firebase is initialized and user is authenticated
    if (Firebase.apps.isNotEmpty) {
      try {
        final authUser = FirebaseAuth.instance.currentUser;
        if (authUser != null && authUser.uid.isNotEmpty) {
          LoggerService.d('[FIRESTORE-USER-WRITE] uid: ${authUser.uid}, authUid: ${authUser.uid}, source: OnboardingNotifier.completeOnboarding, operation: sync onboarding profile');
          final userDocRef = FirebaseFirestore.instance.collection('users').doc(authUser.uid);
          await userDocRef.set({
            'profile': {
              'name': profile.name,
              'gender': profile.gender,
              'ageYears': profile.ageYears,
              'heightCm': profile.heightCm,
              'weightKg': profile.weightKg,
              'goalWeightKg': profile.goalWeightKg,
              'targetBodyFat': profile.targetBodyFat,
              'targetWaist': profile.targetWaist,
              'targetBmi': profile.targetBmi,
              'selectedPlanId': profile.selectedPlanId,
              'onboardingComplete': true,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).timeout(const Duration(seconds: 2));
        }
      } catch (e) {
        LoggerService.w('OnboardingNotifier: Cloud profile sync warning: $e');
      }
    }
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, OnboardingState>(OnboardingNotifier.new);