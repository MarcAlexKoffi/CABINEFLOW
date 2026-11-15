import 'dart:async';

import 'package:cabine_flow/core/resilience/backend_read_stream.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Realtime actif evite le polling rapide, qui reprend apres une panne',
    () async {
      final signals = StreamController<Object?>();
      var calls = 0;
      final subscription = BackendReadStream.watch<int>(
        fetch: () async => ++calls,
        label: 'test.adaptive-polling',
        refreshSignals: () => signals.stream,
        refreshInterval: const Duration(seconds: 1),
        fallbackInterval: const Duration(milliseconds: 5),
        retryInterval: const Duration(milliseconds: 100),
        coalesceDelay: Duration.zero,
      ).listen((_) {});
      signals.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final healthyCalls = calls;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(calls, healthyCalls);
      signals.addError(StateError('WebSocket test failure'));
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(calls, greaterThan(healthyCalls));
      await subscription.cancel();
      await signals.close();
    },
  );
  test(
    'une lecture bloquee expose le timeout puis reprend sans faux vide',
    () async {
      var calls = 0;
      final values = <int>[];
      final errors = <Object>[];
      final recovered = Completer<void>();
      final subscription =
          BackendReadStream.watch<int>(
            fetch: () =>
                ++calls == 1 ? Completer<int>().future : Future.value(42),
            label: 'test.timeout',
            timeout: const Duration(milliseconds: 15),
            retryInterval: const Duration(milliseconds: 5),
          ).listen((value) {
            values.add(value);
            recovered.complete();
          }, onError: (Object error) => errors.add(error));
      await recovered.future.timeout(const Duration(seconds: 2));
      await subscription.cancel();
      expect(errors, [isA<TimeoutException>()]);
      expect(values, [42]);
      expect(calls, 2);
    },
  );

  test(
    'un refus ne boucle pas et une reprise identique efface l erreur',
    () async {
      final signals = StreamController<Object?>();
      final values = <int>[];
      final errors = <Object>[];
      var calls = 0;
      final subscription = BackendReadStream.watch<int>(
        fetch: () async {
          calls++;
          if (calls == 2) throw StateError('access denied');
          return 7;
        },
        label: 'test.permission',
        refreshSignals: () => signals.stream,
        coalesceDelay: Duration.zero,
      ).listen(values.add, onError: (Object error) => errors.add(error));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      signals.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls, 2);
      expect(errors, hasLength(1));
      expect(values, [7]);
      signals.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(values, [7, 7]);
      await subscription.cancel();
      await signals.close();
    },
  );

  test('le polling continue meme si Realtime reste silencieux', () async {
    final signals = StreamController<Object?>();
    var calls = 0;
    final done = Completer<void>();
    final subscription =
        BackendReadStream.watch<int>(
          fetch: () async => ++calls,
          label: 'test.silent-websocket',
          refreshSignals: () => signals.stream,
          refreshInterval: const Duration(milliseconds: 10),
        ).listen((value) {
          if (value == 3) done.complete();
        });
    await done.future.timeout(const Duration(seconds: 2));
    await subscription.cancel();
    await signals.close();
    expect(calls, 3);
  });

  test(
    'les signaux concurrents ne lancent pas de lectures simultanees',
    () async {
      final signals = StreamController<Object?>();
      final first = Completer<int>();
      var calls = 0;
      var active = 0;
      var maximum = 0;
      final done = Completer<void>();
      final subscription =
          BackendReadStream.watch<int>(
            fetch: () async {
              active++;
              if (active > maximum) maximum = active;
              final value = ++calls == 1 ? await first.future : 2;
              active--;
              return value;
            },
            label: 'test.coalescing',
            refreshSignals: () => signals.stream,
            coalesceDelay: const Duration(milliseconds: 1),
          ).listen((value) {
            if (value == 2) done.complete();
          });
      for (var i = 0; i < 20; i++) {
        signals.add(null);
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
      first.complete(1);
      await done.future.timeout(const Duration(seconds: 2));
      await subscription.cancel();
      await signals.close();
      expect(maximum, 1);
      expect(calls, 2);
    },
  );

  test(
    'annuler une lecture retire les signaux et ignore sa reponse tardive',
    () async {
      var cancelled = false;
      final signals = StreamController<Object?>(
        onCancel: () => cancelled = true,
      );
      final pending = Completer<int>();
      final values = <int>[];
      final subscription = BackendReadStream.watch<int>(
        fetch: () => pending.future,
        label: 'test.cancel',
        refreshSignals: () => signals.stream,
      ).listen(values.add);
      await subscription.cancel();
      pending.complete(1);
      await Future<void>.delayed(Duration.zero);
      await signals.close();
      expect(cancelled, isTrue);
      expect(values, isEmpty);
    },
  );

  test('un abonnement Realtime termine est reconnecte', () async {
    var connects = 0;
    final done = Completer<void>();
    final subscription = BackendReadStream.watch<int>(
      fetch: () async => 1,
      label: 'test.reconnect',
      refreshSignals: () {
        connects++;
        if (connects == 2) done.complete();
        return const Stream<Object?>.empty();
      },
      retryInterval: const Duration(milliseconds: 5),
    ).listen((_) {});
    await done.future.timeout(const Duration(seconds: 2));
    await subscription.cancel();
    expect(connects, 2);
  });
}
