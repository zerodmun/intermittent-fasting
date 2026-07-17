import 'package:hive_ce/hive.dart';

part 'fasting_schedule.g.dart';

@HiveType(typeId: 1)
class FastingSchedule extends HiveObject {
  @HiveField(0)
  Map<int, DailySchedule> dailySchedules;

  @HiveField(1)
  DateTime createdAt;

  @HiveField(2)
  DateTime updatedAt;

  FastingSchedule({
    required this.dailySchedules,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Factory constructor to create a default schedule (17:00 to 09:00 for all days).
  factory FastingSchedule.defaultSchedule() {
    final Map<int, DailySchedule> defaults = {};
    for (int day = 1; day <= 7; day++) {
      defaults[day] = DailySchedule(
        fastHour: 17,
        fastMin: 0,
        eatHour: 9,
        eatMin: 0,
      );
    }
    return FastingSchedule(dailySchedules: defaults);
  }

  FastingSchedule copyWith({
    Map<int, DailySchedule>? dailySchedules,
  }) {
    return FastingSchedule(
      dailySchedules: dailySchedules ?? Map.from(this.dailySchedules),
    );
  }

  /// Get fasting start time for a specific weekday.
  DailySchedule getScheduleFor(int weekday) {
    return dailySchedules[weekday] ?? DailySchedule.defaultSchedule();
  }
}

@HiveType(typeId: 2)
class DailySchedule extends HiveObject {
  @HiveField(0)
  int fastHour;

  @HiveField(1)
  int fastMin;

  @HiveField(2)
  int eatHour;

  @HiveField(3)
  int eatMin;

  DailySchedule({
    required this.fastHour,
    required this.fastMin,
    required this.eatHour,
    required this.eatMin,
  });

  factory DailySchedule.defaultSchedule() {
    return DailySchedule(
      fastHour: 17,
      fastMin: 0,
      eatHour: 9,
      eatMin: 0,
    );
  }

  DailySchedule copyWith({
    int? fastHour,
    int? fastMin,
    int? eatHour,
    int? eatMin,
  }) {
    return DailySchedule(
      fastHour: fastHour ?? this.fastHour,
      fastMin: fastMin ?? this.fastMin,
      eatHour: eatHour ?? this.eatHour,
      eatMin: eatMin ?? this.eatMin,
    );
  }

  String get fastTimeFormatted {
    return '${fastHour.toString().padLeft(2, '0')}:${fastMin.toString().padLeft(2, '0')}';
  }

  String get eatTimeFormatted {
    return '${eatHour.toString().padLeft(2, '0')}:${eatMin.toString().padLeft(2, '0')}';
  }

  /// Convert to JSON for export
  Map<String, dynamic> toJson() {
    return {
      'fastHour': fastHour,
      'fastMin': fastMin,
      'eatHour': eatHour,
      'eatMin': eatMin,
    };
  }
}
