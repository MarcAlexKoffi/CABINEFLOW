import 'package:flutter/foundation.dart';

/// Chronométrage sans donnée métier ni identifiant utilisateur.
class StartupTrace {
  StartupTrace._();

  static final Stopwatch _clock = Stopwatch();
  static int _lastMilliseconds = 0;

  static void start() {
    if (!_clock.isRunning) _clock.start();
    mark('flutter-entry');
  }

  static void mark(String stage) {
    if (!_clock.isRunning) _clock.start();
    final int elapsed = _clock.elapsedMilliseconds;
    final int delta = elapsed - _lastMilliseconds;
    _lastMilliseconds = elapsed;
    debugPrint('[IzyTel][Startup][$stage] total=${elapsed}ms delta=${delta}ms');
  }
}
