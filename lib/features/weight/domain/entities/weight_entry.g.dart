// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weight_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WeightEntryAdapter extends TypeAdapter<WeightEntry> {
  @override
  final typeId = 4;

  @override
  WeightEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeightEntry(
      id: fields[0] as String,
      weightKg: (fields[1] as num).toDouble(),
      date: fields[2] as DateTime,
      bodyFatPercentage: (fields[3] as num?)?.toDouble(),
      leanMassKg: (fields[4] as num?)?.toDouble(),
      fatMassKg: (fields[5] as num?)?.toDouble(),
      bmi: (fields[6] as num?)?.toDouble(),
      bmr: (fields[7] as num?)?.toDouble(),
      tdee: (fields[8] as num?)?.toDouble(),
      waistCm: (fields[9] as num?)?.toDouble(),
      neckCm: (fields[10] as num?)?.toDouble(),
      hipCm: (fields[11] as num?)?.toDouble(),
      chestCm: (fields[12] as num?)?.toDouble(),
      leftArmCm: (fields[13] as num?)?.toDouble(),
      rightArmCm: (fields[14] as num?)?.toDouble(),
      leftForearmCm: (fields[15] as num?)?.toDouble(),
      rightForearmCm: (fields[16] as num?)?.toDouble(),
      leftThighCm: (fields[17] as num?)?.toDouble(),
      rightThighCm: (fields[18] as num?)?.toDouble(),
      leftCalfCm: (fields[19] as num?)?.toDouble(),
      rightCalfCm: (fields[20] as num?)?.toDouble(),
      shoulderCm: (fields[21] as num?)?.toDouble(),
      note: fields[22] as String?,
      createdAt: fields[23] as DateTime?,
      updatedAt: fields[24] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, WeightEntry obj) {
    writer
      ..writeByte(25)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.weightKg)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.bodyFatPercentage)
      ..writeByte(4)
      ..write(obj.leanMassKg)
      ..writeByte(5)
      ..write(obj.fatMassKg)
      ..writeByte(6)
      ..write(obj.bmi)
      ..writeByte(7)
      ..write(obj.bmr)
      ..writeByte(8)
      ..write(obj.tdee)
      ..writeByte(9)
      ..write(obj.waistCm)
      ..writeByte(10)
      ..write(obj.neckCm)
      ..writeByte(11)
      ..write(obj.hipCm)
      ..writeByte(12)
      ..write(obj.chestCm)
      ..writeByte(13)
      ..write(obj.leftArmCm)
      ..writeByte(14)
      ..write(obj.rightArmCm)
      ..writeByte(15)
      ..write(obj.leftForearmCm)
      ..writeByte(16)
      ..write(obj.rightForearmCm)
      ..writeByte(17)
      ..write(obj.leftThighCm)
      ..writeByte(18)
      ..write(obj.rightThighCm)
      ..writeByte(19)
      ..write(obj.leftCalfCm)
      ..writeByte(20)
      ..write(obj.rightCalfCm)
      ..writeByte(21)
      ..write(obj.shoulderCm)
      ..writeByte(22)
      ..write(obj.note)
      ..writeByte(23)
      ..write(obj.createdAt)
      ..writeByte(24)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
