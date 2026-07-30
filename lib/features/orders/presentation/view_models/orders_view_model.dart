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

  QueueOrder? _activeOrder;
  bool _isProcessingAction = false;

  QueueOrder? get activeOrder => _activeOrder;

  bool get isProcessingAction => _isProcessingAction;

  bool _isLoading = false;
  String? _errorMessage;
  QueueFilter _selectedFilter = QueueFilter.all;

  List<QueueOrder> _orders = [];
  final Set<String> _processingOrderIds = {};

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  QueueFilter get selectedFilter => _selectedFilter;

  bool get hasOrders => allReadyOrders.isNotEmpty;

  Future<bool> markActiveOrderSuccessful() async {
    final QueueOrder? order = _activeOrder;

    if (order == null || _isProcessingAction) {
      return false;
    }

    _isProcessingAction = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final QueueOrder updatedOrder = await _ordersRepository.markSuccessful(
        orderId: order.id,
      );

      // La commande reste disponible pour l’écran
      // de confirmation du client.
      _activeOrder = updatedOrder;

      return true;
    } catch (error) {
      _errorMessage = error is StateError
          ? error.message.toString()
          : 'Impossible de terminer cette commande.';

      return false;
    } finally {
      _isProcessingAction = false;
      notifyListeners();
    }
  }

  Future<bool> completeCustomerConfirmation({required bool messageSent}) async {
    final QueueOrder? order = _activeOrder;

    if (order == null || _isProcessingAction) {
      return false;
    }

    if (order.status != QueueOrderStatus.awaitingCustomerConfirmation) {
      _errorMessage = 'Cette commande n’attend pas de confirmation client.';

      notifyListeners();

      return false;
    }

    _isProcessingAction = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await _ordersRepository.completeCustomerConfirmation(
        orderId: order.id,
        messageSent: messageSent,
      );

      // Le parcours opérationnel est maintenant terminé.
      _activeOrder = null;

      return true;
    } catch (error) {
      _errorMessage = error is StateError
          ? error.message.toString()
          : 'Impossible de clôturer la confirmation client.';

      return false;
    } finally {
      _isProcessingAction = false;
      notifyListeners();
    }
  }

  Future<bool> markActiveOrderFailed({
    required OrderFailureReason reason,
    String? observation,
  }) async {
    final QueueOrder? order = _activeOrder;

    if (order == null || _isProcessingAction) {
      return false;
    }

    _isProcessingAction = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _ordersRepository.markFailed(
        orderId: order.id,
        reason: reason,
        observation: observation,
      );

      _activeOrder = null;

      return true;
    } catch (error) {
      _errorMessage = error is StateError
          ? error.message.toString()
          : 'Impossible d’enregistrer l’échec.';

      return false;
    } finally {
      _isProcessingAction = false;
      notifyListeners();
    }
  }

  Future<bool> putActiveOrderOnHold() async {
    final QueueOrder? order = _activeOrder;

    if (order == null || _isProcessingAction) {
      return false;
    }

    _isProcessingAction = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final QueueOrder updatedOrder = await _ordersRepository.putOnHold(
        orderId: order.id,
      );

      _orders = [..._orders, updatedOrder];

      _activeOrder = null;

      return true;
    } catch (error) {
      _errorMessage = error is StateError
          ? error.message.toString()
          : 'Impossible de remettre la commande en attente.';

      return false;
    } finally {
      _isProcessingAction = false;
      notifyListeners();
    }
  }

  List<QueueOrder> get allReadyOrders {
    final List<QueueOrder> readyOrders = _orders.where((QueueOrder order) {
      return order.status == QueueOrderStatus.paidReady;
    }).toList();

    readyOrders.sort((QueueOrder firstOrder, QueueOrder secondOrder) {
      final DateTime firstDate = firstOrder.paidAt ?? firstOrder.createdAt;

      final DateTime secondDate = secondOrder.paidAt ?? secondOrder.createdAt;

      return firstDate.compareTo(secondDate);
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
    final DateTime? paidAt = order.paidAt;

    if (paidAt == null) {
      return 0;
    }

    final int minutes = DateTime.now().difference(paidAt).inMinutes;

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
      final QueueOrder updatedOrder = await _ordersRepository.takeCharge(
        orderId: orderId,
        operatorId: operatorId,
      );

      _activeOrder = updatedOrder;

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
