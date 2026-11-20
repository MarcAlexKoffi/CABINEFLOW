import 'dart:async';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/domain/repositories/shared_order_queue_repository.dart';
import 'package:flutter/foundation.dart';

class SharedOrderQueueViewModel extends ChangeNotifier {
  SharedOrderQueueViewModel(this.repository);
  final SharedOrderQueueRepository repository;
  StreamSubscription<SharedQueueSnapshot>? _subscription;
  final Map<String, int> _closedVersions = {};
  final List<SharedQueueCursor?> _pages = [null];
  int _generation = 0;
  SharedQueueSnapshot? snapshot;
  String? errorMessage, busyOrderId;
  bool loading = true, fresh = false, _disposed = false;
  List<AvailableSharedOrder> get orders => snapshot?.orders ?? const [];
  int get totalCount => snapshot?.totalCount ?? 0;
  int get pageNumber => _pages.length;
  bool get hasPreviousPage => _pages.length > 1;
  bool get hasNextPage => snapshot?.nextCursor != null;
  bool get canAct => fresh && !loading && busyOrderId == null;

  void start() {
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    _subscription = repository
        .watchAvailableOrders(after: _pages.last)
        .listen(
          (value) {
            if (generation == _generation) _apply(value);
          },
          onError: (Object error) {
            if (_disposed || generation != _generation) return;
            loading = false;
            fresh = false;
            errorMessage =
                'La disponibilité doit être revérifiée. Vérifiez votre connexion puis réessayez.';
            notifyListeners();
          },
        );
  }

  void nextPage() {
    if (!canAct || !hasNextPage) return;
    _pages.add(snapshot!.nextCursor);
    _changePage();
  }

  void previousPage() {
    if (!canAct || !hasPreviousPage) return;
    _pages.removeLast();
    _changePage();
  }

  void _changePage() {
    snapshot = null;
    loading = true;
    fresh = false;
    errorMessage = null;
    start();
    notifyListeners();
  }

  void _apply(SharedQueueSnapshot value) {
    if (_disposed) return;
    if (snapshot != null && value.serverNow.isBefore(snapshot!.serverNow)) {
      return;
    }
    final visible = value.orders
        .where((order) => order.version > (_closedVersions[order.id] ?? -1))
        .toList(growable: false);
    if (visible.isEmpty && hasPreviousPage) {
      _pages.removeRange(1, _pages.length);
      _changePage();
      return;
    }
    snapshot = SharedQueueSnapshot(
      orders: visible,
      serverNow: value.serverNow,
      enabled: value.enabled,
      totalCount: (value.totalCount - (value.orders.length - visible.length))
          .clamp(0, value.totalCount),
      nextCursor: value.nextCursor,
    );
    loading = false;
    fresh = true;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final generation = _generation;
    try {
      final value = await repository.fetchAvailableOrders(after: _pages.last);
      if (generation == _generation) _apply(value);
    } catch (_) {
      if (_disposed || generation != _generation) return;
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
        totalCount: (totalCount - 1).clamp(0, totalCount),
        nextCursor: snapshot!.nextCursor,
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
          totalCount: (totalCount - 1).clamp(0, totalCount),
          nextCursor: snapshot!.nextCursor,
        );
        errorMessage = 'Cette commande a déjà été acceptée par un autre Agent.';
      } else if (raw.contains('AGENT_ACTIVE_ORDER_EXISTS')) {
        errorMessage =
            'Vous avez déjà une commande en cours. Veuillez la finaliser avant d’en accepter une nouvelle.';
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
