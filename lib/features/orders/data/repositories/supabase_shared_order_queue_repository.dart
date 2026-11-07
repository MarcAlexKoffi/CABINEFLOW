import 'dart:async';
import 'package:cabine_flow/core/supabase/supabase_realtime_refetch.dart';
import 'package:cabine_flow/features/orders/data/repositories/supabase_phase4_assignment_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/shared_order_queue_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSharedOrderQueueRepository
    implements SharedOrderQueueRepository, OrderSupervisionRepository {
  SupabaseSharedOrderQueueRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  static Map<String, dynamic> _object(Object? raw) {
    if (raw is! Map) throw const FormatException('Réponse de file invalide.');
    return Map<String, dynamic>.from(raw);
  }

  @override
  Future<SharedQueueSnapshot> fetchAvailableOrders() async {
    final data = _object(
      await _client
          .rpc('izytel_shared_available')
          .timeout(const Duration(seconds: 12)),
    );
    final orders = (data['orders'] as List)
        .map((row) => AvailableSharedOrder.fromJson(_object(row)))
        .toList(growable: false);
    return SharedQueueSnapshot(
      orders: orders,
      serverNow: DateTime.parse(data['server_now'] as String),
      enabled: data['enabled'] == true,
    );
  }

  @override
  Future<QueueOrder> claimAvailableOrder(AvailableSharedOrder order) async {
    final result = _object(
      await _client
          .rpc(
            'izytel_shared_claim',
            params: {
              'p_order_id': order.id,
              'p_expected_version': order.version,
            },
          )
          .timeout(const Duration(seconds: 15)),
    );
    if (!const ['claimed', 'already_owned'].contains(result['outcome'])) {
      throw const FormatException('Acceptation non confirmée.');
    }
    // The RPC returns the authorized canonical row from the same transaction.
    return SupabasePhase4AssignmentRepository(
      client: _client,
    ).parseCanonicalOrder(_object(result['order']));
  }

  Stream<T> _watch<T>(
    Future<T> Function() fetch,
    String label, {
    bool alerts = false,
  }) {
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    bool lastReadSucceeded = false;
    controller = StreamController<T>(
      onListen: () {
        subscription =
            SupabaseRealtimeRefetch.watch<T>(
              client: _client,
              label: label,
              independentPolling: true,
              fallbackInterval: const Duration(seconds: 3),
              signals: [
                const SupabaseRealtimeSignal(
                  table: 'izytel_shared_queue_signals',
                  primaryKey: ['zone_id'],
                ),
                if (alerts)
                  const SupabaseRealtimeSignal(
                    table: 'izytel_order_delay_alerts',
                    primaryKey: ['id'],
                  ),
              ],
              fetch: () async {
                try {
                  final value = await fetch();
                  lastReadSucceeded = true;
                  return value;
                } catch (error, stack) {
                  lastReadSucceeded = false;
                  if (!controller.isClosed) controller.addError(error, stack);
                  rethrow;
                }
              },
            ).listen(
              (value) {
                // Cached values after a failed read must never restore action freshness.
                if (lastReadSucceeded && !controller.isClosed) {
                  controller.add(value);
                }
              },
              onError: (Object error, StackTrace stack) {
                if (!controller.isClosed) controller.addError(error, stack);
              },
            );
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Stream<SharedQueueSnapshot> watchAvailableOrders() =>
      _watch(fetchAvailableOrders, 'SharedQueue.watch');

  @override
  Future<OrderSupervisionSnapshot> fetchSupervision() async {
    final data = _object(
      await _client
          .rpc('izytel_order_supervision')
          .timeout(const Duration(seconds: 12)),
    );
    return OrderSupervisionSnapshot(
      serverNow: DateTime.parse(data['server_now'] as String),
      orders: (data['orders'] as List).map(_object).toList(growable: false),
      alerts: (data['alerts'] as List).map(_object).toList(growable: false),
    );
  }

  @override
  Stream<OrderSupervisionSnapshot> watchSupervision() =>
      _watch(fetchSupervision, 'OrderSupervision.watch', alerts: true);
}
