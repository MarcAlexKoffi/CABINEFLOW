import 'dart:async';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/shared_order_queue_repository.dart';
import 'package:flutter/foundation.dart';

class SharedOrderQueueViewModel extends ChangeNotifier {
  SharedOrderQueueViewModel(this.repository);
  final SharedOrderQueueRepository repository;
  StreamSubscription<SharedQueueSnapshot>? _subscription;
  final Map<String, int> _closedVersions = {};
  SharedQueueSnapshot? snapshot;
  String? errorMessage, busyOrderId;
  bool loading = true, fresh = false, _disposed = false;
  List<AvailableSharedOrder> get orders => snapshot?.orders ?? const [];
  bool get canAct => fresh && !loading && busyOrderId == null;

  void start() {
    _subscription = repository.watchAvailableOrders().listen(
      _apply,
      onError: (Object error) {
        if (_disposed) return;
        loading = false;
        fresh = false;
        errorMessage =
            'La disponibilité doit être revérifiée. Vérifiez votre connexion puis réessayez.';
        notifyListeners();
      },
    );
  }

  void _apply(SharedQueueSnapshot value) {
    if (_disposed) return;
    if (snapshot != null && value.serverNow.isBefore(snapshot!.serverNow)) {
      return;
    }
    snapshot = SharedQueueSnapshot(
      orders: value.orders
          .where((order) => order.version > (_closedVersions[order.id] ?? -1))
          .toList(growable: false),
      serverNow: value.serverNow,
      enabled: value.enabled,
    );
    loading = false;
    fresh = true;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    try {
      _apply(await repository.fetchAvailableOrders());
    } catch (_) {
      if (_disposed) return;
      loading = false;
      fresh = false;
      errorMessage =
          'Impossible d’actualiser la file. Réessayez après reconnexion.';
      notifyListeners();
    }
  }

  Future<QueueOrder?> claim(AvailableSharedOrder order) async {
    if (!canAct || !order.canAccept) return null;
    busyOrderId = order.id;
    errorMessage = null;
    notifyListeners();
    try {
      final claimed = await repository.claimAvailableOrder(order);
      if (_disposed) return claimed;
      _closedVersions[order.id] = order.version;
      snapshot = SharedQueueSnapshot(
        orders: orders
            .where((item) => item.id != order.id)
            .toList(growable: false),
        serverNow: snapshot!.serverNow,
        enabled: snapshot!.enabled,
      );
      return claimed;
    } catch (error) {
      if (_disposed) return null;
      final raw = error.toString().toUpperCase();
      if (raw.contains('ORDER_ALREADY_TAKEN')) {
        _closedVersions[order.id] = order.version;
        snapshot = SharedQueueSnapshot(
          orders: orders
              .where((item) => item.id != order.id)
              .toList(growable: false),
          serverNow: snapshot!.serverNow,
          enabled: snapshot!.enabled,
        );
        errorMessage = 'Cette commande a déjà été acceptée par un autre Agent.';
      } else if (raw.contains('AGENT_NOT_ELIGIBLE')) {
        errorMessage =
            'Votre disponibilité, votre réseau ou votre capacité ne permet plus cette prise en charge.';
        fresh = false;
      } else {
        // The server may have committed before a response was lost. Retrying
        // this same order/version is safe; never fabricate an accepted result.
        errorMessage =
            'L’acceptation n’a pas pu être confirmée. Actualisez puis réessayez.';
        fresh = false;
      }
      return null;
    } finally {
      if (!_disposed) {
        busyOrderId = null;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
