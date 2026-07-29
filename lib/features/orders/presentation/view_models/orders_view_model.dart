import 'dart:async';

import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:flutter/foundation.dart';

enum QueueFilter { all, orange, mtn, moov }

class OrdersViewModel extends ChangeNotifier {
  OrdersViewModel({required OrdersRepository ordersRepository})
    : _ordersRepository = ordersRepository {
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (Timer timer) {
      notifyListeners();
    });
  }

  final OrdersRepository _ordersRepository;

  Timer? _clockTimer;

  bool _isLoading = false;
  String? _errorMessage;
  QueueFilter _selectedFilter = QueueFilter.all;

  List<QueueOrder> _orders = [];
  final Set<String> _processingOrderIds = {};

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  QueueFilter get selectedFilter => _selectedFilter;

  bool get hasOrders => allReadyOrders.isNotEmpty;

  List<QueueOrder> get allReadyOrders {
    final List<QueueOrder> readyOrders = _orders.where((QueueOrder order) {
      return order.status == QueueOrderStatus.paidReady;
    }).toList();

    readyOrders.sort((QueueOrder firstOrder, QueueOrder secondOrder) {
      return firstOrder.paidAt.compareTo(secondOrder.paidAt);
    });

    return readyOrders;
  }

  List<QueueOrder> get filteredOrders {
    final List<QueueOrder> orders = allReadyOrders;

    switch (_selectedFilter) {
      case QueueFilter.all:
        return orders;

      case QueueFilter.orange:
        return orders.where((QueueOrder order) {
          return order.network == MobileNetwork.orange;
        }).toList();

      case QueueFilter.mtn:
        return orders.where((QueueOrder order) {
          return order.network == MobileNetwork.mtn;
        }).toList();

      case QueueFilter.moov:
        return orders.where((QueueOrder order) {
          return order.network == MobileNetwork.moov;
        }).toList();
    }
  }

  int get averageWaitingMinutes {
    final List<QueueOrder> orders = allReadyOrders;

    if (orders.isEmpty) {
      return 0;
    }

    final int totalMinutes = orders.fold<int>(0, (int total, QueueOrder order) {
      return total + waitingMinutes(order);
    });

    return (totalMinutes / orders.length).round();
  }

  Future<void> loadQueue() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      _orders = await _ordersRepository.fetchPaidQueue();
    } catch (_) {
      _errorMessage = 'Impossible de charger la file d’attente.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectFilter(QueueFilter filter) {
    if (_selectedFilter == filter) {
      return;
    }

    _selectedFilter = filter;
    notifyListeners();
  }

  int countForFilter(QueueFilter filter) {
    switch (filter) {
      case QueueFilter.all:
        return allReadyOrders.length;

      case QueueFilter.orange:
        return allReadyOrders.where((QueueOrder order) {
          return order.network == MobileNetwork.orange;
        }).length;

      case QueueFilter.mtn:
        return allReadyOrders.where((QueueOrder order) {
          return order.network == MobileNetwork.mtn;
        }).length;

      case QueueFilter.moov:
        return allReadyOrders.where((QueueOrder order) {
          return order.network == MobileNetwork.moov;
        }).length;
    }
  }

  int waitingMinutes(QueueOrder order) {
    final int minutes = DateTime.now().difference(order.paidAt).inMinutes;

    if (minutes < 0) {
      return 0;
    }

    return minutes;
  }

  bool isUrgent(QueueOrder order) {
    return waitingMinutes(order) >= 5;
  }

  int positionOf(String orderId) {
    final int index = allReadyOrders.indexWhere((QueueOrder order) {
      return order.id == orderId;
    });

    if (index == -1) {
      return 0;
    }

    return index + 1;
  }

  bool isTakingCharge(String orderId) {
    return _processingOrderIds.contains(orderId);
  }

  Future<bool> takeCharge({
    required String orderId,
    required String operatorId,
  }) async {
    if (_processingOrderIds.contains(orderId)) {
      return false;
    }

    _processingOrderIds.add(orderId);
    _errorMessage = null;

    notifyListeners();

    try {
      await _ordersRepository.takeCharge(
        orderId: orderId,
        operatorId: operatorId,
      );

      _orders = _orders.where((QueueOrder order) {
        return order.id != orderId;
      }).toList();

      return true;
    } catch (error) {
      _errorMessage = error is StateError
          ? error.message.toString()
          : 'Impossible de prendre en charge cette commande.';

      return false;
    } finally {
      _processingOrderIds.remove(orderId);
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }
}
