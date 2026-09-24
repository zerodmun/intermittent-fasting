extension DurationExtensions on Duration {
  /// Format as "HH:MM" (e.g. "16:08")
  String get toHHMM {
    final h = inHours.toString().padLeft(2, '0');
    final m = (inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Format as "HH:MM:SS" (e.g. "16:08:42")
  String get toHHMMSS {
    final h = inHours.toString().padLeft(2, '0');
    final m = (inMinutes % 60).toString().padLeft(2, '0');
    final s = (inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Human-readable format (e.g. "16h 8m" or "45m")
  String get toReadable {
    if (inHours > 0) {
      final m = inMinutes % 60;
      return m > 0 ? '${inHours}h ${m}m' : '${inHours}h';
    }
    if (inMinutes > 0) {
      return '${inMinutes}m';
    }
    return '${inSeconds}s';
  }

  /// Compact format for charts (e.g. "16.1")
  double get toHoursDecimal => inMinutes / 60.0;

  /// Format as "Xd Xh Xm" for longer durations
  String get toFullReadable {
    final parts = <String>[];
    if (inDays > 0) parts.add('${inDays}d');
    if (inHours % 24 > 0) parts.add('${inHours % 24}h');
    return parts.isEmpty ? '0m' : parts.join(' ');
  }

  /// Format as spelled out duration (e.g. "17 hours 40 minutes" or "18 hours" or "45 minutes")
  String get toDetailedSpelledOut {
    final h = inHours;
    final m = inMinutes % 60;
    if (h > 0 && m > 0) {
      final hourStr = h == 1 ? 'hour' : 'hours';
      final minStr = m == 1 ? 'minute' : 'minutes';
      return '$h $hourStr $m $minStr';
    } else if (h > 0) {
      final hourStr = h == 1 ? 'hour' : 'hours';
      return '$h $hourStr';
    } else if (m > 0) {
      final minStr = m == 1 ? 'minute' : 'minutes';
      return '$m $minStr';
    }
    return '$inSeconds seconds';
  }
}