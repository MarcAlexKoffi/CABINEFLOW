import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRealtimeSignal {
  const SupabaseRealtimeSignal({
    required this.table,
    required this.primaryKey,
  });

  final String table;
  final List<String> primaryKey;
}

/// Reads once, then refetches only when one of the supplied Realtime signal
/// tables changes. A slow polling loop is kept only as a safety net if the
/// websocket cannot be maintained.
///
/// The signal tables are deliberately decoupled from the fetched payload. This
/// lets domains such as Finance listen to the tiny `finance_change_feed` row
/// instead of subscribing to every large Phase 5 table independently.
class SupabaseRealtimeRefetch {
  const SupabaseRealtimeRefetch._();

  static const Duration fallbackPollInterval = Duration(seconds: 60);
  static const Duration signalCoalesceDelay = Duration(milliseconds: 120);

  static Stream<T> watch<T>({
    required SupabaseClient client,
    required Future<T> Function() fetch,
    required String label,
    required List<SupabaseRealtimeSignal> signals,
    Duration fallbackInterval = fallbackPollInterval,
  }) async* {
    T? lastSuccessful;
    bool hasLastSuccessful = false;

    try {
      final T initial = await fetch();
      lastSuccessful = initial;
      hasLastSuccessful = true;
      yield initial;
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        '$label.initial',
        error,
        stackTrace: stackTrace,
      );
      if (!BackendFailurePolicy.canRetryRead(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }

    if (signals.isNotEmpty) {
      StreamController<void>? controller;
      final List<StreamSubscription<List<Map<String, dynamic>>>> subscriptions =
          <StreamSubscription<List<Map<String, dynamic>>>>[];
      Timer? coalesceTimer;
      int primedSignals = 0;
      int completedSignals = 0;
      final List<bool> primed = List<bool>.filled(signals.length, false);

      void requestRefresh() {
        coalesceTimer?.cancel();
        coalesceTimer = Timer(signalCoalesceDelay, () {
          final StreamController<void>? target = controller;
          if (target != null && !target.isClosed) {
            target.add(null);
          }
        });
      }

      try {
        await _syncRealtimeAuth(client);
        final StreamController<void> signalController = StreamController<void>();
        controller = signalController;

        for (int index = 0; index < signals.length; index += 1) {
          final SupabaseRealtimeSignal signal = signals[index];
          final Stream<List<Map<String, dynamic>>> stream = client
              .from(signal.table)
              .stream(primaryKey: signal.primaryKey);
          late final StreamSubscription<List<Map<String, dynamic>>> subscription;
          subscription = stream.listen(
            (_) {
              if (!primed[index]) {
                primed[index] = true;
                primedSignals += 1;
                // Once every signal has produced its initial snapshot, refetch
                // once to close the race between the REST read above and the
                // Realtime subscriptions becoming active.
                if (primedSignals == signals.length) {
                  requestRefresh();
                }
                return;
              }
              requestRefresh();
            },
            onError: (Object error, StackTrace stackTrace) {
              final StreamController<void>? target = controller;
              if (target != null && !target.isClosed) {
                target.addError(error, stackTrace);
              }
            },
            onDone: () {
              completedSignals += 1;
              final StreamController<void>? target = controller;
              if (completedSignals == signals.length &&
                  target != null &&
                  !target.isClosed) {
                unawaited(target.close());
              }
            },
          );
          subscriptions.add(subscription);
        }

        await for (final _ in signalController.stream) {
          try {
            final T value = await fetch();
            lastSuccessful = value;
            hasLastSuccessful = true;
            yield value;
          } catch (error, stackTrace) {
            IzyTelLog.backendError(
              '$label.refetch',
              error,
              stackTrace: stackTrace,
            );
            if (!BackendFailurePolicy.canRetryRead(error)) {
              Error.throwWithStackTrace(error, stackTrace);
            }
            if (hasLastSuccessful) {
              yield lastSuccessful as T;
            }
          }
        }
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          '$label.realtime',
          error,
          stackTrace: stackTrace,
        );
      } finally {
        coalesceTimer?.cancel();
        for (final StreamSubscription<List<Map<String, dynamic>>> subscription
            in subscriptions) {
          await subscription.cancel();
        }
        final StreamController<void>? target = controller;
        if (target != null && !target.isClosed) {
          await target.close();
        }
      }
    }

    int consecutiveFailures = 0;
    while (true) {
      await Future<void>.delayed(
        BackendFailurePolicy.retryDelay(
          baseDelay: fallbackInterval,
          consecutiveFailures: consecutiveFailures,
        ),
      );
      try {
        final T value = await fetch();
        lastSuccessful = value;
        hasLastSuccessful = true;
        consecutiveFailures = 0;
        yield value;
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          '$label.fallback',
          error,
          stackTrace: stackTrace,
        );
        if (!BackendFailurePolicy.canRetryRead(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        consecutiveFailures += 1;
        if (hasLastSuccessful) {
          yield lastSuccessful as T;
        }
      }
    }
  }

  static Future<void> _syncRealtimeAuth(SupabaseClient client) async {
    final String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null || token.trim().isEmpty) return;
    await client.realtime.setAuth(token);
  }
}
