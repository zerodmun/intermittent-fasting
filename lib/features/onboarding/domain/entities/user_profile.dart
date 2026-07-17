import 'package:hive_ce/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 0)
class UserProfile extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String gender;

  @HiveField(2)
  int ageYears;

  @HiveField(3)
  double heightCm;

  @HiveField(4)
  double weightKg;

  @HiveField(5)
  double goalWeightKg;

  @HiveField(6)
  double targetBodyFat;

  @HiveField(7)
  double targetWaist;

  @HiveField(8)
  double targetBmi;

  @HiveField(9)
  String selectedPlanId;

  @HiveField(10)
  bool onboardingComplete;

  @HiveField(11)
  DateTime createdAt;

  @HiveField(12)
  DateTime updatedAt;

  UserProfile({
    required this.name,
    required this.gender,
    required this.ageYears,
    required this.heightCm,
    required this.weightKg,
    required this.goalWeightKg,
    required this.targetBodyFat,
    required this.targetWaist,
    required this.targetBmi,
    required this.selectedPlanId,
    this.onboardingComplete = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  UserProfile copyWith({
    String? name,
    String? gender,
    int? ageYears,
    double? heightCm,
    double? weightKg,
    double? goalWeightKg,
    double? targetBodyFat,
    double? targetWaist,
    double? targetBmi,
    String? selectedPlanId,
    bool? onboardingComplete,
  }) {
    return UserProfile(
      name: name ?? this.name,
      gender: gender ?? this.gender,
      ageYears: ageYears ?? this.ageYears,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goalWeightKg: goalWeightKg ?? this.goalWeightKg,
      targetBodyFat: targetBodyFat ?? this.targetBodyFat,
      targetWaist: targetWaist ?? this.targetWaist,
      targetBmi: targetBmi ?? this.targetBmi,
      selectedPlanId: selectedPlanId ?? this.selectedPlanId,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));
  double get bmr {
    if (gender.toLowerCase() == 'male') {
      return 88.362 + (13.397 * weightKg) + (4.799 * heightCm) - (5.677 * ageYears);
    } else {
      return 447.593 + (9.247 * weightKg) + (3.098 * heightCm) - (4.330 * ageYears);
    }
  }
}