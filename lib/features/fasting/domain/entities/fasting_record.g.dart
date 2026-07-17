// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fasting_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FastingRecordAdapter extends TypeAdapter<FastingRecord> {
  @override
  final typeId = 3;

  @override
  FastingRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FastingRecord(
      id: fields[0] as String,
      planName: fields[1] as String,
      fastingMinutes: (fields[2] as num).toInt(),
      eatingMinutes: (fields[3] as num).toInt(),
      startTime: fields[4] as DateTime,
      endTime: fields[5] as DateTime?,
      status: fields[6] == null ? 'active' : fields[6] as String,
      note: fields[7] as String?,
      reason: fields[8] as String?,
      createdAt: fields[9] as DateTime?,
      updatedAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, FastingRecord obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.planName)
      ..writeByte(2)
      ..write(obj.fastingMinutes)
      ..writeByte(3)
      ..write(obj.eatingMinutes)
      ..writeByte(4)
      ..write(obj.startTime)
      ..writeByte(5)
      ..write(obj.endTime)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.note)
      ..writeByte(8)
      ..write(obj.reason)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FastingRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
