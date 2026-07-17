import 'package:hive_ce/hive.dart';

part 'fasting_record.g.dart';

@HiveType(typeId: 3)
class FastingRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String planName;

  @HiveField(2)
  int fastingMinutes;

  @HiveField(3)
  int eatingMinutes;

  @HiveField(4)
  DateTime startTime;

  @HiveField(5)
  DateTime? endTime;

  @HiveField(6)
  String status;

  @HiveField(7)
  String? note;

  @HiveField(8)
  String? reason;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime updatedAt;

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
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

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
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Duration get fastingDuration => Duration(minutes: fastingMinutes);
  Duration get eatingDuration => Duration(minutes: eatingMinutes);

  Duration get actualDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  DateTime get expectedFastingEnd => startTime.add(Duration(minutes: fastingMinutes));
  DateTime get expectedEatingEnd => expectedFastingEnd.add(Duration(minutes: eatingMinutes));

  bool get isCompleted => status == 'completed';
  bool get isActive => status == 'active';
  bool get isSkipped => status == 'skipped';
  bool get isCancelled => status == 'cancelled';
}
