/// Represents the current phase of a fasting cycle.
enum FastingPhase {
  /// No active session.
  idle,

  /// User is currently fasting.
  fasting,

  /// Fasting window completed; user is in eating window.
  eating,
}
