import 'dart:async';

import 'package:cabine_flow/core/supabase/supabase_realtime_refetch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;

  setUp(() {
    client = SupabaseClient('http://127.0.0.1:1', 'synthetic-public-key');
  });
  tearDown(() => client.dispose());

  test(
    'Finance polls even when a connected Realtime signal stays silent',
    () async {
      final signals = StreamController<Object?>();
      final values = <int>[];
      final done = Completer<void>();
      var calls = 0;
      final subscription =
          SupabaseRealtimeRefetch.watch<int>(
            client: client,
            fetch: () async => ++calls,
            label: 'finance.silent-signal',
            signals: const [],
            independentPolling: true,
            refreshSignals: () => signals.stream,
            fallbackInterval: const Duration(milliseconds: 20),
          ).listen((value) {
            values.add(value);
            if (value == 3) done.complete();
          });
      signals.add(null);
      await done.future.timeout(const Duration(seconds: 2));
      await subscription.cancel();
      await signals.close();
      expect(values, [1, 2, 3]);
    },
  );

  test('Realtime error does not become a failed Finance snapshot', () async {
    final signals = StreamController<Object?>();
    final errors = <Object>[];
    final done = Completer<void>();
    var calls = 0;
    final subscription =
        SupabaseRealtimeRefetch.watch<int>(
          client: client,
          fetch: () async => ++calls,
          label: 'finance.failed-signal',
          signals: const [],
          independentPolling: true,
          refreshSignals: () => signals.stream,
          fallbackInterval: const Duration(milliseconds: 20),
        ).listen((value) {
          if (value == 2) done.complete();
        }, onError: errors.add);
    signals.addError(
      const RealtimeSubscribeException(RealtimeSubscribeStatus.channelError),
    );
    await done.future.timeout(const Duration(seconds: 2));
    await subscription.cancel();
    await signals.close();
    expect(errors, isEmpty);
    expect(calls, 2);
  });

  test(
    'canonical 403 remains visible without an automatic retry loop',
    () async {
      final errors = <Object>[];
      var calls = 0;
      final done = Completer<void>();
      final subscription =
          SupabaseRealtimeRefetch.watch<int>(
            client: client,
            fetch: () async {
              calls++;
              throw const PostgrestException(
                message: 'ADMIN_REQUIRED',
                code: '42501',
              );
            },
            label: 'finance.denied-read',
            signals: const [],
            independentPolling: true,
            fallbackInterval: const Duration(milliseconds: 20),
          ).listen(
            (_) {},
            onError: (Object error) {
              errors.add(error);
              done.complete();
            },
          );
      await done.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await subscription.cancel();
      expect(errors, [isA<PostgrestException>()]);
      expect(calls, 1);
    },
  );

  test('cancelling a Finance stream cancels polling and its signals', () async {
    var cancelled = false;
    var calls = 0;
    final signals = StreamController<Object?>(onCancel: () => cancelled = true);
    final loaded = Completer<void>();
    final subscription = SupabaseRealtimeRefetch.watch<int>(
      client: client,
      fetch: () async => ++calls,
      label: 'finance.cancel',
      signals: const [],
      independentPolling: true,
      refreshSignals: () => signals.stream,
      fallbackInterval: const Duration(milliseconds: 20),
    ).listen((_) => loaded.complete());
    await loaded.future;
    await subscription.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await signals.close();
    expect(cancelled, isTrue);
    expect(calls, 1);
  });
}
