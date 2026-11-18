import 'dart:async';
import 'package:cabine_flow/app/core/resilience/backend_failure_policy.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/app/domain/repositories/shared_order_queue_repository.dart';
import 'package:cabine_flow/app/modules/agent_orders/controllers/shared_order_queue_view_model.dart';
import 'package:flutter/foundation.dart';

/// Home reads the same personal and shared queues as the Orders tab.
class AgentHomeViewModel extends ChangeNotifier {
  AgentHomeViewModel({required this.agentId, required this.repository}) {
    if (repository is SharedOrderQueueRepository) {
      _shared = SharedOrderQueueViewModel(
        repository as SharedOrderQueueRepository,
      )..addListener(_changed);
    }
  }
  final String agentId;
  final OrdersRepository repository;
  SharedOrderQueueViewModel? _shared;
  StreamSubscription<List<QueueOrder>>? _subscription;
  List<QueueOrder> _orders = const [];
  bool _loading = true, _loaded = false, _disposed = false;
  int _revision = 0;
  String? _error;
  Future<void>? _refreshing;

  bool get loading => _loading || (_shared?.loading ?? false);
  bool get hasData => _loaded && (_shared == null || _shared!.snapshot != null);
  String? get error => _error ?? _shared?.errorMessage;
  bool get sharedEnabled => _shared?.snapshot?.enabled == true;
  static bool _completed(QueueOrder o) => const {
    QueueOrderStatus.completed,
    QueueOrderStatus.awaitingCustomerConfirmation,
    QueueOrderStatus.failed,
    QueueOrderStatus.cancelled,
    QueueOrderStatus.refunded,
  }.contains(o.status);
  int get assignedToAccept => _orders
      .where((o) => o.assignmentStatus == OrderAssignmentStatus.assigned)
      .length;
  int get availableCount {
    if (!sharedEnabled) return 0;
    final ownIds = _orders
        .where(
          (o) =>
              o.assignmentStatus == OrderAssignmentStatus.assigned ||
              o.assignmentStatus == OrderAssignmentStatus.accepted &&
                  !_completed(o),
        )
        .map((o) => o.id)
        .toSet();
    return _shared!.orders.map((o) => o.id).toSet().difference(ownIds).length;
  }

  int get toAccept => assignedToAccept + availableCount;
  int get inProgress => _orders
      .where(
        (o) =>
            o.assignmentStatus == OrderAssignmentStatus.accepted &&
            !_completed(o),
      )
      .length;
  int get completed => _orders
      .where(
        (o) =>
            o.assignmentStatus == OrderAssignmentStatus.accepted &&
            _completed(o),
      )
      .length;

  void start() {
    _subscription = repository
        .watchAssignedOrders(agentId: agentId)
        .listen(_apply, onError: (Object error) => _fail(error));
    _shared?.start();
  }

  void _apply(List<QueueOrder> value) {
    if (_disposed) return;
    _revision++;
    _orders = {
      for (final o in value)
        if (o.assignedAgentId == agentId) o.id: o,
    }.values.toList(growable: false);
    _loading = false;
    _loaded = true;
    _error = null;
    _changed();
  }

  void _fail(Object error) {
    if (_disposed) return;
    _revision++;
    _loading = false;
    _error = 'Impossible d’actualiser tes commandes. Réessaie.';
    if (!BackendFailurePolicy.canRetryRead(error)) {
      _orders = const [];
      _loaded = false;
    }
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  Future<void> _refresh() async {
    final revision = _revision;
    await Future.wait([
      () async {
        try {
          final orders = await repository
              .fetchAssignedOrders(agentId: agentId)
              .timeout(const Duration(seconds: 12));
          // A newer stream update wins over an older pull-to-refresh response.
          if (!_disposed && revision == _revision) _apply(orders);
        } catch (error) {
          if (!_disposed && revision == _revision) _fail(error);
        }
      }(),
      if (_shared != null) _shared!.refresh(),
    ]);
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _shared?.removeListener(_changed);
    _shared?.dispose();
    super.dispose();
  }
}
