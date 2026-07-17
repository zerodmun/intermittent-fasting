// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fasting_schedule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FastingScheduleAdapter extends TypeAdapter<FastingSchedule> {
  @override
  final typeId = 1;

  @override
  FastingSchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FastingSchedule(
      dailySchedules: (fields[0] as Map).cast<int, DailySchedule>(),
      createdAt: fields[1] as DateTime?,
      updatedAt: fields[2] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, FastingSchedule obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.dailySchedules)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FastingScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DailyScheduleAdapter extends TypeAdapter<DailySchedule> {
  @override
  final typeId = 2;

  @override
  DailySchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailySchedule(
      fastHour: (fields[0] as num).toInt(),
      fastMin: (fields[1] as num).toInt(),
      eatHour: (fields[2] as num).toInt(),
      eatMin: (fields[3] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, DailySchedule obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.fastHour)
      ..writeByte(1)
      ..write(obj.fastMin)
      ..writeByte(2)
      ..write(obj.eatHour)
      ..writeByte(3)
      ..write(obj.eatMin);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
