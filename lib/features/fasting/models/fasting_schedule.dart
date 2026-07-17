import 'package:hive_ce/hive.dart';

/// Represents a user's repeating daily fasting schedules for the 7 days of the week.
class FastingSchedule extends HiveObject {
  // Key: 1 (Monday) to 7 (Sunday)
  // Value: {'fastHour': int, 'fastMin': int, 'eatHour': int, 'eatMin': int}
  Map<int, Map<String, int>> dailySchedules;

  FastingSchedule({
    required this.dailySchedules,
  });

  /// Factory constructor to create a default schedule (17:00 to 09:00 for all days).
  factory FastingSchedule.defaultSchedule() {
    final Map<int, Map<String, int>> defaults = {};
    for (int day = 1; day <= 7; day++) {
      defaults[day] = {
        'fastHour': 17,
        'fastMin': 0,
        'eatHour': 9,
        'eatMin': 0,
      };
    }
    return FastingSchedule(dailySchedules: defaults);
  }

  FastingSchedule copyWith({
    Map<int, Map<String, int>>? dailySchedules,
  }) {
    return FastingSchedule(
      dailySchedules: dailySchedules ?? Map.from(this.dailySchedules),
    );
  }

  /// Get fasting start time for a specific weekday.
  Map<String, int> getScheduleFor(int weekday) {
    return dailySchedules[weekday] ?? {
      'fastHour': 17,
      'fastMin': 0,
      'eatHour': 9,
      'eatMin': 0,
    };
  }
}

/// Manual Hive type adapter for [FastingSchedule].
class FastingScheduleAdapter extends TypeAdapter<FastingSchedule> {
  @override
  final int typeId = 3;

  @override
  FastingSchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    final rawMap = fields[0] as Map?;
    final Map<int, Map<String, int>> schedules = {};

    if (rawMap != null) {
      rawMap.forEach((key, val) {
        final intDay = (key as num).toInt();
        final valMap = Map<String, dynamic>.from(val as Map);
        schedules[intDay] = {
          'fastHour': (valMap['fastHour'] as num?)?.toInt() ?? 17,
          'fastMin': (valMap['fastMin'] as num?)?.toInt() ?? 0,
          'eatHour': (valMap['eatHour'] as num?)?.toInt() ?? 9,
          'eatMin': (valMap['eatMin'] as num?)?.toInt() ?? 0,
        };
      });
    }

    if (schedules.isEmpty) {
      return FastingSchedule.defaultSchedule();
    }

    return FastingSchedule(dailySchedules: schedules);
  }

  @override
  void write(BinaryWriter writer, FastingSchedule obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.dailySchedules);
  }
}
