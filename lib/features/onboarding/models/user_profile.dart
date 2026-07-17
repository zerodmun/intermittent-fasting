import 'package:hive_ce/hive.dart';

/// User profile stored locally via Hive.
class UserProfile extends HiveObject {
  String name;
  String gender;
  double heightCm;
  double weightKg;
  double goalWeightKg;
  String selectedPlanId;
  bool onboardingComplete;
  int ageYears;
  double targetBodyFat;
  double targetWaist;
  double targetBmi;

  UserProfile({
    required this.name,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.goalWeightKg,
    required this.selectedPlanId,
    this.onboardingComplete = false,
    this.ageYears = 25,
    this.targetBodyFat = 15.0,
    this.targetWaist = 80.0,
    this.targetBmi = 22.0,
  });

  UserProfile copyWith({
    String? name,
    String? gender,
    double? heightCm,
    double? weightKg,
    double? goalWeightKg,
    String? selectedPlanId,
    bool? onboardingComplete,
    int? ageYears,
    double? targetBodyFat,
    double? targetWaist,
    double? targetBmi,
  }) {
    return UserProfile(
      name: name ?? this.name,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goalWeightKg: goalWeightKg ?? this.goalWeightKg,
      selectedPlanId: selectedPlanId ?? this.selectedPlanId,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      ageYears: ageYears ?? this.ageYears,
      targetBodyFat: targetBodyFat ?? this.targetBodyFat,
      targetWaist: targetWaist ?? this.targetWaist,
      targetBmi: targetBmi ?? this.targetBmi,
    );
  }
}

/// Manual Hive type adapter for [UserProfile].
class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 0;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      name: fields[0] as String,
      gender: fields[1] as String,
      heightCm: fields[2] as double,
      weightKg: fields[3] as double,
      goalWeightKg: fields[4] as double,
      selectedPlanId: fields[5] as String,
      onboardingComplete: fields[6] as bool? ?? false,
      ageYears: fields[7] as int? ?? 25,
      targetBodyFat: fields[8] as double? ?? 15.0,
      targetWaist: fields[9] as double? ?? 80.0,
      targetBmi: fields[10] as double? ?? 22.0,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.gender)
      ..writeByte(2)
      ..write(obj.heightCm)
      ..writeByte(3)
      ..write(obj.weightKg)
      ..writeByte(4)
      ..write(obj.goalWeightKg)
      ..writeByte(5)
      ..write(obj.selectedPlanId)
      ..writeByte(6)
      ..write(obj.onboardingComplete)
      ..writeByte(7)
      ..write(obj.ageYears)
      ..writeByte(8)
      ..write(obj.targetBodyFat)
      ..writeByte(9)
      ..write(obj.targetWaist)
      ..writeByte(10)
      ..write(obj.targetBmi);
  }
}
