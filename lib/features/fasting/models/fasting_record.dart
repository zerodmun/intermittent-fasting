import 'package:hive_ce/hive.dart';

/// A completed or in-progress fasting session.
class FastingRecord extends HiveObject {
  String id;
  String planName;
  int fastingMinutes;
  int eatingMinutes;
  DateTime startTime;
  DateTime? endTime;
  String status; // 'active', 'completed', 'cancelled', 'skipped'
  String? note;
  String? reason;

  FastingRecord({
    required this.id,
    required this.planName,
    required this.fastingMinutes,
    required this.eatingMinutes,
    required this.startTime,
    this.endTime,
    this.status = 'active',
    this.note,
    this.reason,
  });

  Duration get fastingDuration => Duration(minutes: fastingMinutes);
  Duration get eatingDuration => Duration(minutes: eatingMinutes);

  Duration get actualDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  DateTime get expectedFastingEnd =>
      startTime.add(Duration(minutes: fastingMinutes));

  DateTime get expectedEatingEnd =>
      expectedFastingEnd.add(Duration(minutes: eatingMinutes));

  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isActive => status == 'active';
  bool get isSkipped => status == 'skipped';

  FastingRecord copyWith({
    String? id,
    String? planName,
    int? fastingMinutes,
    int? eatingMinutes,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    String? note,
    String? reason,
  }) {
    return FastingRecord(
      id: id ?? this.id,
      planName: planName ?? this.planName,
      fastingMinutes: fastingMinutes ?? this.fastingMinutes,
      eatingMinutes: eatingMinutes ?? this.eatingMinutes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      note: note ?? this.note,
      reason: reason ?? this.reason,
    );
  }
}

/// Manual Hive type adapter for [FastingRecord].
class FastingRecordAdapter extends TypeAdapter<FastingRecord> {
  @override
  final int typeId = 1;

  @override
  FastingRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FastingRecord(
      id: fields[0] as String,
      planName: fields[1] as String,
      fastingMinutes: fields[2] as int,
      eatingMinutes: fields[3] as int,
      startTime: fields[4] as DateTime,
      endTime: fields[5] as DateTime?,
      status: fields[6] as String? ?? 'active',
      note: fields[7] as String?,
      reason: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FastingRecord obj) {
    writer
      ..writeByte(9)
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
      ..write(obj.reason);
  }
}
