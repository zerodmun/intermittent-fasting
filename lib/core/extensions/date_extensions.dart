extension DateTimeExtensions on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  DateTime get startOfDay => DateTime(year, month, day);
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59);

  DateTime get startOfWeek {
    final diff = weekday - DateTime.monday;
    return subtract(Duration(days: diff)).startOfDay;
  }

  DateTime get endOfWeek {
    return startOfWeek.add(const Duration(days: 6)).endOfDay;
  }

  DateTime get startOfMonth => DateTime(year, month, 1);
  DateTime get endOfMonth => DateTime(year, month + 1, 0, 23, 59, 59);

  /// Check if this date is between [start] and [end] (inclusive)
  bool isBetween(DateTime start, DateTime end) {
    final thisDay = DateTime(year, month, day);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return thisDay.isAfter(startDay.subtract(const Duration(days: 1))) &&
        thisDay.isBefore(endDay.add(const Duration(days: 1)));
  }

  /// Returns a copy of this DateTime with the time set to the given hour and minute
  DateTime atTime(int hour, [int minute = 0]) {
    return DateTime(year, month, day, hour, minute);
  }

  /// Returns the date for the given weekday (1=Monday) relative to this date's week
  DateTime dateForWeekday(int weekday) {
    final start = startOfWeek;
    return start.add(Duration(days: weekday - 1));
  }
}