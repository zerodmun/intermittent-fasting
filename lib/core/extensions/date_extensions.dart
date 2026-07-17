import 'package:intl/intl.dart';

/// Convenience extensions on [DateTime].
extension DateExtensions on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
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

  String get weekdayName => DateFormat.EEEE().format(this);
  String get weekdayShort => DateFormat.E().format(this);
  String get monthName => DateFormat.MMMM().format(this);
  String get monthShort => DateFormat.MMM().format(this);

  String get formatted => DateFormat('MMM d, yyyy').format(this);
  String get formattedShort => DateFormat('MMM d').format(this);
  String get formattedTime => DateFormat('h:mm a').format(this);
  String get formattedDateTime => DateFormat('MMM d, h:mm a').format(this);

  String get relativeLabel {
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    return formatted;
  }
}
