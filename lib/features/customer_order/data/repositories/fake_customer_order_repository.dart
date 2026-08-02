import 'dart:async';

import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/payment_declaration.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

class FakeCustomerOrderRepository implements CustomerOrderRepository {
  int _sequence = 0;

  final Map<String, CustomerOrderReceipt> _orders =
      <String, CustomerOrderReceipt>{};
  final Map<String, StreamController<CustomerOrderReceipt>> _controllers =
      <String, StreamController<CustomerOrderReceipt>>{};

  @override
  Future<CustomerOrderReceipt> createOrder({
    required CustomerOrderDraft draft,
  }) async {
    _validateDraft(draft);

    await Future<void>.delayed(const Duration(milliseconds: 150));

    final DateTime now = DateTime.now();
    _sequence++;

    final CustomerOrderReceipt receipt = CustomerOrderReceipt(
      id: 'customer-order-${now.microsecondsSinceEpoch}',
      reference: _buildReference(now, _sequence),
      draft: draft,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 6)),
      status: QueueOrderStatus.awaitingPayment,
      paymentStatus: OrderPaymentStatus.notDeclared,
    );

    _orders[receipt.id] = receipt;
    _controllers[receipt.id] = StreamController<CustomerOrderReceipt>.broadcast();

    return receipt;
  }

  @override
  Future<CustomerOrderReceipt> declarePayment({
    required CustomerOrderReceipt order,
    required PaymentDeclaration declaration,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final CustomerOrderReceipt? currentOrder = _orders[order.id];

    if (currentOrder == null) {
      throw StateError('La commande est introuvable.');
    }

    if (currentOrder.status == QueueOrderStatus.paymentToVerify &&
        currentOrder.paymentStatus == OrderPaymentStatus.declared) {
      return currentOrder;
    }

    if (currentOrder.status != QueueOrderStatus.awaitingPayment ||
        currentOrder.paymentStatus != OrderPaymentStatus.notDeclared) {
      throw StateError(
        'Le paiement de cette commande a déjà été déclaré ou son statut a changé.',
      );
    }

    final CustomerOrderReceipt updatedOrder = currentOrder.copyWith(
      status: QueueOrderStatus.paymentToVerify,
      paymentStatus: OrderPaymentStatus.declared,
      paymentDeclaredAt: DateTime.now(),
      paymentDeclaration: declaration,
    );

    _orders[order.id] = updatedOrder;
    _controllers[order.id]?.add(updatedOrder);

    return updatedOrder;
  }

  @override
  Stream<CustomerOrderReceipt> watchOrder({
    required CustomerOrderReceipt order,
  }) async* {
    final CustomerOrderReceipt? currentOrder = _orders[order.id];

    if (currentOrder == null) {
      throw StateError('La commande suivie est introuvable.');
    }

    yield currentOrder;
    yield* _controllers[order.id]!.stream;
  }

  void simulateOrderUpdate(CustomerOrderReceipt order) {
    if (!_orders.containsKey(order.id)) {
      throw StateError('La commande est introuvable.');
    }

    _orders[order.id] = order;
    _controllers[order.id]?.add(order);
  }

  String _buildReference(DateTime date, int sequence) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    final String number = sequence.toString().padLeft(4, '0');

    return 'CF-$year$month$day-$number';
  }

  void _validateDraft(CustomerOrderDraft draft) {
    if (draft.identity == null ||
        draft.service == null ||
        draft.network == null ||
        draft.selectedOfferLabel == null ||
        (draft.amount ?? 0) <= 0 ||
        draft.beneficiaryNumber == null) {
      throw StateError('La commande est incomplète. Revenez au récapitulatif.');
    }
  }
}
