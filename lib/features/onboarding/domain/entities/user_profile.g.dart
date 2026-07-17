// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final typeId = 0;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      name: fields[0] as String,
      gender: fields[1] as String,
      ageYears: (fields[2] as num).toInt(),
      heightCm: (fields[3] as num).toDouble(),
      weightKg: (fields[4] as num).toDouble(),
      goalWeightKg: (fields[5] as num).toDouble(),
      targetBodyFat: (fields[6] as num).toDouble(),
      targetWaist: (fields[7] as num).toDouble(),
      targetBmi: (fields[8] as num).toDouble(),
      selectedPlanId: fields[9] as String,
      onboardingComplete: fields[10] == null ? false : fields[10] as bool,
      createdAt: fields[11] as DateTime?,
      updatedAt: fields[12] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.gender)
      ..writeByte(2)
      ..write(obj.ageYears)
      ..writeByte(3)
      ..write(obj.heightCm)
      ..writeByte(4)
      ..write(obj.weightKg)
      ..writeByte(5)
      ..write(obj.goalWeightKg)
      ..writeByte(6)
      ..write(obj.targetBodyFat)
      ..writeByte(7)
      ..write(obj.targetWaist)
      ..writeByte(8)
      ..write(obj.targetBmi)
      ..writeByte(9)
      ..write(obj.selectedPlanId)
      ..writeByte(10)
      ..write(obj.onboardingComplete)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
