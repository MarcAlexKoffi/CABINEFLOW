import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';

/// A bounded canonical read with independent Realtime and polling refreshes.
/// Errors remain visible to consumers; a later successful read clears them.
/// No cached value is substituted for a failed authorization or network read.
class BackendReadStream {
  const BackendReadStream._();

  static const Duration readTimeout = Duration(seconds: 15);

  static Stream<T> watch<T>({
    required Future<T> Function() fetch,
    required String label,
    Stream<Object?> Function()? refreshSignals,
    Duration timeout = readTimeout,
    Duration refreshInterval = const Duration(seconds: 60),
    Duration? fallbackInterval,
    Duration retryInterval = const Duration(seconds: 2),
    Duration coalesceDelay = const Duration(milliseconds: 120),
  }) {
    late StreamController<T> controller;
    StreamSubscription<Object?>? signals;
    Timer? readTimer;
    Timer? coalesceTimer;
    Timer? reconnectTimer;
    bool cancelled = false;
    bool reading = false;
    bool pending = false;
    int failures = 0;
    bool signalsAvailable = false;

    Future<void> read() async {
      if (cancelled) return;
      if (reading) {
        pending = true;
        return;
      }
      reading = true;
      readTimer?.cancel();
      Duration? nextRead;
      try {
        final value = await fetch().timeout(timeout);
        if (cancelled) return;
        failures = 0;
        controller.add(value);
        nextRead = signalsAvailable
            ? refreshInterval
            : (fallbackInterval ?? refreshInterval);
      } catch (error, stackTrace) {
        if (cancelled) return;
        IzyTelLog.backendError(label, error, stackTrace: stackTrace);
        controller.addError(error, stackTrace);
        if (BackendFailurePolicy.canRetryRead(error)) {
          nextRead = BackendFailurePolicy.retryDelay(
            baseDelay: retryInterval,
            consecutiveFailures: failures++,
          );
        }
      } finally {
        reading = false;
        if (!cancelled) {
          if (pending) {
            pending = false;
            readTimer = Timer(coalesceDelay, read);
          } else if (nextRead != null) {
            readTimer = Timer(nextRead, read);
          }
        }
      }
    }

    void refresh() {
      if (cancelled) return;
      coalesceTimer?.cancel();
      coalesceTimer = Timer(coalesceDelay, read);
    }

    late void Function() connect;
    void reconnect() {
      if (cancelled) return;
      reconnectTimer?.cancel();
      reconnectTimer = Timer(retryInterval, connect);
    }

    connect = () {
      if (cancelled || refreshSignals == null) return;
      signals?.cancel();
      try {
        signals = refreshSignals().listen(
          (_) {
            signalsAvailable = true;
            refresh();
          },
          onError: (Object error, StackTrace stackTrace) {
            IzyTelLog.backendError(
              '$label.realtime',
              error,
              stackTrace: stackTrace,
            );
            // A signal failure says nothing about the canonical REST read.
            signalsAvailable = false;
            refresh();
            reconnect();
          },
          onDone: () {
            signalsAvailable = false;
            refresh();
            reconnect();
          },
          cancelOnError: true,
        );
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          '$label.realtime',
          error,
          stackTrace: stackTrace,
        );
        reconnect();
      }
    };

    controller = StreamController<T>(
      onListen: () {
        unawaited(read());
        connect();
      },
      onCancel: () async {
        cancelled = true;
        readTimer?.cancel();
        coalesceTimer?.cancel();
        reconnectTimer?.cancel();
        await signals?.cancel();
      },
    );
    return controller.stream;
  }

  static String readErrorMessage(Object error, {required String fallback}) {
    if (BackendFailurePolicy.canRetryRead(error)) {
      return 'Connexion indisponible ou trop lente. Réessayez dans un instant.';
    }
    if ((error is FirebaseException &&
            const {
              'permission-denied',
              'unauthenticated',
            }.contains(error.code)) ||
        (error is PostgrestException &&
            const {
              '42501',
              'PGRST301',
              'PGRST302',
              'PGRST303',
            }.contains(error.code))) {
      return 'Accès refusé ou session expirée. Reconnectez-vous puis réessayez.';
    }
    return fallback;
  }
}
