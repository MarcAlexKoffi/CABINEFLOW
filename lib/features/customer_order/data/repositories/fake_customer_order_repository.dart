import 'dart:async';

import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/payment_declaration.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/services/order_expiration_policy.dart';

class FakeCustomerOrderRepository implements CustomerOrderRepository {
  FakeCustomerOrderRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  int _sequence = 0;

  final Map<String, CustomerOrderReceipt> _orders =
      <String, CustomerOrderReceipt>{};
  final Map<String, StreamController<CustomerOrderReceipt>> _controllers =
      <String, StreamController<CustomerOrderReceipt>>{};
  final StreamController<List<CustomerOrderReceipt>> _historyController =
      StreamController<List<CustomerOrderReceipt>>.broadcast();

  @override
  Future<CustomerOrderReceipt> createOrder({
    required CustomerOrderDraft draft,
  }) async {
    _validateDraft(draft);

    await Future<void>.delayed(const Duration(milliseconds: 150));

    final DateTime now = _now();
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
    _controllers[receipt.id] =
        StreamController<CustomerOrderReceipt>.broadcast();
    _emitHistory();

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

    if ((currentOrder.status == QueueOrderStatus.paymentToVerify ||
            currentOrder.status == QueueOrderStatus.expired) &&
        currentOrder.paymentStatus == OrderPaymentStatus.declared) {
      return currentOrder;
    }

    final bool canDeclareBeforeExpiration =
        currentOrder.status == QueueOrderStatus.awaitingPayment &&
        currentOrder.paymentStatus == OrderPaymentStatus.notDeclared;
    final bool canDeclareAfterExpiration =
        currentOrder.status == QueueOrderStatus.expired &&
        (currentOrder.paymentStatus == OrderPaymentStatus.expired ||
            currentOrder.paymentStatus == OrderPaymentStatus.notDeclared);

    if (!canDeclareBeforeExpiration && !canDeclareAfterExpiration) {
      throw StateError(
        'Le paiement de cette commande a déjà été déclaré ou son statut a changé.',
      );
    }

    final DateTime declaredAt = _now();
    final bool declaredAfterExpiration =
        currentOrder.status == QueueOrderStatus.expired ||
        !declaredAt.toUtc().isBefore(currentOrder.expiresAt.toUtc());
    final CustomerOrderReceipt updatedOrder = currentOrder.copyWith(
      status: declaredAfterExpiration
          ? QueueOrderStatus.expired
          : QueueOrderStatus.paymentToVerify,
      paymentStatus: OrderPaymentStatus.declared,
      paymentDeclaredAt: declaredAt,
      paymentDeclaration: declaration,
      expiredAt: declaredAfterExpiration
          ? currentOrder.expiredAt ?? declaredAt
          : currentOrder.expiredAt,
    );

    _orders[order.id] = updatedOrder;
    _controllers[order.id]?.add(updatedOrder);
    _emitHistory();

    return updatedOrder;
  }

  @override
  Stream<List<CustomerOrderReceipt>> watchCustomerOrders() async* {
    _expireDueOrders();
    yield _sortedOrders();
    yield* _historyController.stream;
  }

  @override
  Stream<CustomerOrderReceipt> watchOrder({
    required CustomerOrderReceipt order,
  }) async* {
    _expireDueOrders();
    final CustomerOrderReceipt? currentOrder = _orders[order.id];

    if (currentOrder == null) {
      throw StateError('La commande suivie est introuvable.');
    }

    yield currentOrder;
    yield* _controllers[order.id]!.stream;
  }

  @override
  Future<CustomerOrderReceipt> synchronizeExpiration({
    required CustomerOrderReceipt order,
  }) async {
    _expireDueOrders();
    return _orders[order.id] ?? order;
  }

  @override
  Future<CustomerOrderReceipt> recoverOrder({
    required String reference,
    required String whatsappInput,
  }) async {
    final WhatsappPhoneNumber whatsapp = WhatsappPhoneNumber.parse(
      whatsappInput,
    );
    final String normalizedReference = reference.trim().toUpperCase();

    for (final CustomerOrderReceipt order in _orders.values) {
      if (order.reference.toUpperCase() == normalizedReference &&
          order.draft.identity?.whatsappNumber.normalized ==
              whatsapp.normalized) {
        return order;
      }
    }

    throw StateError('Commande introuvable ou informations incorrectes.');
  }

  void _expireDueOrders() {
    final DateTime now = _now();
    bool historyChanged = false;

    for (final MapEntry<String, CustomerOrderReceipt> entry
        in _orders.entries.toList()) {
      final CustomerOrderReceipt order = entry.value;

      if (!OrderExpirationPolicy.shouldExpire(
        status: order.status,
        paymentStatus: order.paymentStatus,
        expiresAt: order.expiresAt,
        now: now,
      )) {
        continue;
      }

      final CustomerOrderReceipt expiredOrder = order.copyWith(
        status: QueueOrderStatus.expired,
        paymentStatus: OrderExpirationPolicy.paymentStatusAfterExpiration(
          order.paymentStatus,
        ),
        expiredAt: now,
      );
      _orders[entry.key] = expiredOrder;
      _controllers[entry.key]?.add(expiredOrder);
      historyChanged = true;
    }

    if (historyChanged) {
      _emitHistory();
    }
  }

  void simulateOrderUpdate(CustomerOrderReceipt order) {
    if (!_orders.containsKey(order.id)) {
      throw StateError('La commande est introuvable.');
    }

    _orders[order.id] = order;
    _controllers[order.id]?.add(order);
    _emitHistory();
  }

  List<CustomerOrderReceipt> _sortedOrders() {
    final List<CustomerOrderReceipt> orders = _orders.values.toList();
    orders.sort((CustomerOrderReceipt first, CustomerOrderReceipt second) {
      return second.createdAt.compareTo(first.createdAt);
    });
    return orders;
  }

  void _emitHistory() {
    if (!_historyController.isClosed) {
      _historyController.add(_sortedOrders());
    }
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
