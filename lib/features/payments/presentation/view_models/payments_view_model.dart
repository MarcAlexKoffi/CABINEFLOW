import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:flutter/foundation.dart';

enum PaymentOrderFilter {
  all,
  linkToSend,
  awaitingPayment,
  confirmed,
}

class PaymentsViewModel extends ChangeNotifier {
  PaymentsViewModel({
    required OrdersRepository ordersRepository,
  }) : _ordersRepository = ordersRepository;

  final OrdersRepository _ordersRepository;

  List<QueueOrder> _orders = [];

  final Set<String> _processingOrderIds = {};

  PaymentOrderFilter _selectedFilter = PaymentOrderFilter.all;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  PaymentOrderFilter get selectedFilter => _selectedFilter;

  List<QueueOrder> get allOrders => List<QueueOrder>.unmodifiable(_orders);

  List<QueueOrder> get visibleOrders {
    Iterable<QueueOrder> result = _orders;

    switch (_selectedFilter) {
      case PaymentOrderFilter.all:
        break;

      case PaymentOrderFilter.linkToSend:
        result = result.where((QueueOrder order) {
          return order.status == QueueOrderStatus.awaitingPayment &&
              order.paymentRequestSentAt == null;
        });
        break;

      case PaymentOrderFilter.awaitingPayment:
        result = result.where((QueueOrder order) {
          return order.status == QueueOrderStatus.awaitingPayment &&
              order.paymentRequestSentAt != null;
        });
        break;

      case PaymentOrderFilter.confirmed:
        result = result.where((QueueOrder order) {
          return order.paidAt != null && order.paymentReference != null;
        });
        break;
    }

    return result.toList();
  }

  int countForFilter(PaymentOrderFilter filter) {
    switch (filter) {
      case PaymentOrderFilter.all:
        return _orders.length;

      case PaymentOrderFilter.linkToSend:
        return _orders.where((QueueOrder order) {
          return order.status == QueueOrderStatus.awaitingPayment &&
              order.paymentRequestSentAt == null;
        }).length;

      case PaymentOrderFilter.awaitingPayment:
        return _orders.where((QueueOrder order) {
          return order.status == QueueOrderStatus.awaitingPayment &&
              order.paymentRequestSentAt != null;
        }).length;

      case PaymentOrderFilter.confirmed:
        return _orders.where((QueueOrder order) {
          return order.paidAt != null && order.paymentReference != null;
        }).length;
    }
  }

  Future<void> loadPayments() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      _orders = await _ordersRepository.fetchPaymentTrackingOrders();
    } catch (_) {
      _errorMessage = 'Impossible de charger les paiements.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectFilter(PaymentOrderFilter filter) {
    if (_selectedFilter == filter) {
      return;
    }

    _selectedFilter = filter;

    notifyListeners();
  }

  bool isProcessing(String orderId) {
    return _processingOrderIds.contains(orderId);
  }

  Future<bool> confirmPayment({
    required QueueOrder order,
    String? paymentReference,
  }) async {
    if (_processingOrderIds.contains(order.id)) {
      return false;
    }

    _processingOrderIds.add(order.id);
    _errorMessage = null;

    notifyListeners();

    try {
      final QueueOrder updatedOrder = await _ordersRepository.confirmPayment(
        orderId: order.id,
        paidAt: DateTime.now(),
        paymentReference: paymentReference,
      );

      _replaceOrder(updatedOrder);

      return true;
    } catch (error) {
      _errorMessage = error is StateError
          ? error.message.toString()
          : 'Impossible de confirmer ce paiement.';

      return false;
    } finally {
      _processingOrderIds.remove(order.id);

      notifyListeners();
    }
  }

  Future<void> refreshAfterPaymentLinkSent() async {
    await loadPayments();
  }

  void _replaceOrder(QueueOrder updatedOrder) {
    _orders = _orders.map((QueueOrder order) {
      if (order.id == updatedOrder.id) {
        return updatedOrder;
      }

      return order;
    }).toList();
  }
}