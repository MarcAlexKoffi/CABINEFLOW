import 'dart:async';

import 'package:cabine_flow/app/core/logging/izytel_log.dart';
import 'package:cabine_flow/app/core/resilience/backend_failure_policy.dart';
import 'package:cabine_flow/app/core/resilience/backend_read_stream.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRealtimeSignal {
  const SupabaseRealtimeSignal({required this.table, required this.primaryKey});

  final String table;
  final List<String> primaryKey;
}

/// Reads immediately, then refetches when one of the supplied Realtime signal
/// tables changes. A slow polling loop is kept only as a safety net if the
/// websocket stays silent or cannot be maintained. Signals never carry payload errors.
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
    bool independentPolling = false,
    Stream<Object?> Function()? refreshSignals,
  }) {
    T? lastSuccessful;
    bool hasLastSuccessful = false;
    return BackendReadStream.watch<T>(
      label: label,
      refreshInterval: fallbackInterval,
      refreshSignals:
          refreshSignals ??
          (signals.isEmpty ? null : () => _watchSignals(client, signals)),
      fetch: () async {
        try {
          final value = await fetch();
          lastSuccessful = value;
          hasLastSuccessful = true;
          return value;
        } catch (error, stackTrace) {
          // Read-only legacy consumers retain their last successful value.
          // Action-sensitive consumers receive every canonical read error.
          if (!independentPolling &&
              hasLastSuccessful &&
              BackendFailurePolicy.canRetryRead(error)) {
            IzyTelLog.backendError(label, error, stackTrace: stackTrace);
            return lastSuccessful as T;
          }
          rethrow;
        }
      },
    );
  }

  static Future<void> _syncRealtimeAuth(SupabaseClient client) async {
    final String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null || token.trim().isEmpty) return;
    await client.realtime.setAuth(token);
  }

  static Stream<Object?> _watchSignals(
    SupabaseClient client,
    List<SupabaseRealtimeSignal> signals,
  ) {
    late final StreamController<Object?> controller;
    final subscriptions = <StreamSubscription<List<Map<String, dynamic>>>>[];
    bool cancelled = false;
    int completed = 0;

    Future<void> connect() async {
      try {
        await _syncRealtimeAuth(client).timeout(BackendReadStream.readTimeout);
        if (cancelled) return;
        for (final signal in signals) {
          subscriptions.add(
            client
                .from(signal.table)
                .stream(primaryKey: signal.primaryKey)
                .listen(
                  (rows) {
                    if (!cancelled) controller.add(null);
                  },
                  onError: (Object error, StackTrace stackTrace) {
                    if (!cancelled) controller.addError(error, stackTrace);
                  },
                  onDone: () {
                    completed++;
                    if (!cancelled && completed == signals.length) {
                      unawaited(controller.close());
                    }
                  },
                ),
          );
        }
      } catch (error, stackTrace) {
        if (!cancelled) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<Object?>(
      onListen: () => unawaited(connect()),
      onCancel: () async {
        cancelled = true;
        for (final subscription in subscriptions) {
          try {
            await subscription.cancel();
          } catch (error, stackTrace) {
            IzyTelLog.backendError(
              'SupabaseRealtimeRefetch.cancel',
              error,
              stackTrace: stackTrace,
            );
          }
        }
      },
    );
    return controller.stream;
  }
}
