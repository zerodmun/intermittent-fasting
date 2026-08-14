class StartupDiag {
  static final Stopwatch _stopwatch = Stopwatch();
  static bool _hasLoggedMainScreenReady = false;

  static void start() {
    _hasLoggedMainScreenReady = false;
    _stopwatch.reset();
    _stopwatch.start();
    // ignore: avoid_print
    print('[STARTUP-DIAG] main() START');
  }

  static void log(String step) {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }
    final ms = _stopwatch.elapsedMilliseconds;
    // ignore: avoid_print
    print('[STARTUP-DIAG] $step: ${ms}ms');
  }

  static void logMainScreenReady() {
    if (_hasLoggedMainScreenReady) return;
    _hasLoggedMainScreenReady = true;
    log('Main screen ready');
  }
}
