/// Convenience extensions on [Duration].
extension DurationExtensions on Duration {
  /// Format as "HH:MM" (e.g. "16:08").
  String get toHHMM {
    final h = inHours.toString().padLeft(2, '0');
    final m = (inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Format as "HH:MM:SS" (e.g. "16:08:42").
  String get toHHMMSS {
    final h = inHours.toString().padLeft(2, '0');
    final m = (inMinutes % 60).toString().padLeft(2, '0');
    final s = (inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Human-readable format (e.g. "16h 8m" or "45m").
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

  /// Compact format for charts (e.g. "16.1").
  double get toHoursDecimal => inMinutes / 60.0;
}
