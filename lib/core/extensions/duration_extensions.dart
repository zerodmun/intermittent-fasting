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
    if (inMinutes % 60 > 0) parts.add('${inMinutes % 60}m');
    return parts.isEmpty ? '0m' : parts.join(' ');
  }
}