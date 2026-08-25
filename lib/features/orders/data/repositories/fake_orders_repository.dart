import 'dart:async';

import 'package:cabine_flow/features/orders/domain/models/create_order_request.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';

class FakeOrdersRepository implements OrdersRepository, OrderHistoryRepository {
  FakeOrdersRepository({this.isTest = false});

  final bool isTest;
  List<QueueOrder>? _orders;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void _notify() => _changes.add(null);

  Future<void> _delay([int ms = 400]) async {
    if (isTest) return;
    await Future<void>.delayed(Duration(milliseconds: ms));
  }

  @override
  Future<QueueOrder> markPaymentRequestSent({required String orderId}) async {
    await _delay(500);

    final int index = _findOrderIndex(orderId);
    final QueueOrder currentOrder = _orders![index];

    if (currentOrder.status != QueueOrderStatus.awaitingPayment) {
      throw StateError('Cette commande n’est pas en attente de paiement.');
    }

    final QueueOrder updatedOrder = currentOrder.copyWith(
      paymentRequestSentAt: DateTime.now(),
    );

    _orders![index] = updatedOrder;

    return updatedOrder;
  }

  @override
  Future<List<QueueOrder>> fetchPaymentTrackingOrders() async {
    await _delay(450);

    _orders ??= _createInitialOrders();

    final List<QueueOrder> paymentOrders = _orders!.where((QueueOrder order) {
      final bool isOperatorPaymentInProgress =
          order.source == OrderSource.operatorApp &&
          order.status == QueueOrderStatus.awaitingPayment;
      final bool isCustomerPaymentToVerify =
          order.source == OrderSource.customerWeb &&
          order.paymentStatus == OrderPaymentStatus.declared &&
          (order.status == QueueOrderStatus.paymentToVerify ||
              order.status == QueueOrderStatus.awaitingPayment ||
              order.status == QueueOrderStatus.expired);
      final bool wasManuallyConfirmed =
          order.paymentStatus == OrderPaymentStatus.confirmed &&
          order.paymentReference != null &&
          order.paymentReference!.trim().isNotEmpty;

      return isOperatorPaymentInProgress ||
          isCustomerPaymentToVerify ||
          wasManuallyConfirmed;
    }).toList();

    paymentOrders.sort((QueueOrder firstOrder, QueueOrder secondOrder) {
      final DateTime firstDate =
          firstOrder.paidAt ??
          firstOrder.paymentDeclaredAt ??
          firstOrder.paymentRequestSentAt ??
          firstOrder.createdAt;

      final DateTime secondDate =
          secondOrder.paidAt ??
          secondOrder.paymentDeclaredAt ??
          secondOrder.paymentRequestSentAt ??
          secondOrder.createdAt;

      return secondDate.compareTo(firstDate);
    });

    return List<QueueOrder>.unmodifiable(paymentOrders);
  }

  @override
  Future<QueueOrder> confirmPayment({
    required String orderId,
    required DateTime paidAt,
    String? paymentReference,
  }) async {
    await _delay(650);

    final int index = _findOrderIndex(orderId);
    final QueueOrder currentOrder = _orders![index];

    final bool canConfirm =
        currentOrder.status == QueueOrderStatus.awaitingPayment ||
        currentOrder.status == QueueOrderStatus.paymentToVerify ||
        currentOrder.hasPaymentToReviewAfterExpiration;

    if (!canConfirm ||
        currentOrder.paymentStatus == OrderPaymentStatus.confirmed) {
      throw StateError('Cette commande n’est plus en attente de paiement.');
    }

    final String cleanedReference = paymentReference?.trim() ?? '';

    final String finalReference;

    if (cleanedReference.isNotEmpty) {
      finalReference = cleanedReference.toUpperCase();
    } else {
      final String timestamp = paidAt.millisecondsSinceEpoch.toString();

      final String shortTimestamp = timestamp.length > 8
          ? timestamp.substring(timestamp.length - 8)
          : timestamp;

      finalReference = 'MAN-$shortTimestamp';
    }

    final QueueOrder updatedOrder = currentOrder.copyWith(
      status: QueueOrderStatus.paidReady,
      paymentStatus: OrderPaymentStatus.confirmed,
      paidAt: paidAt,
      paymentConfirmedAt: paidAt,
      paymentReference: finalReference,
    );

    _orders![index] = updatedOrder;

    return updatedOrder;
  }

  @override
  Future<List<QueueOrder>> fetchOrderHistory() async {
    await _delay(450);

    _orders ??= _createInitialOrders();

    final List<QueueOrder> orders = List<QueueOrder>.from(_orders!);
    orders.sort((QueueOrder first, QueueOrder second) {
      return second.createdAt.compareTo(first.createdAt);
    });

    return List<QueueOrder>.unmodifiable(orders);
  }

  @override
  Future<QueueOrder> fetchOrderById({required String orderId}) async {
    await _delay(250);
    final int index = _findOrderIndex(orderId);
    return _orders![index];
  }

  @override
  Future<List<QueueOrder>> fetchPaidQueue() async {
    await _delay(700);

    _orders ??= _createInitialOrders();

    return List<QueueOrder>.unmodifiable(
      _orders!.where((QueueOrder order) {
        return order.status == QueueOrderStatus.paidReady;
      }),
    );
  }

  @override
  Future<QueueOrder> assignToAgent({
    required String orderId,
    required String agentId,
    required String assignedByUserId,
  }) async {
    await _delay(350);
    final int index = _findOrderIndex(orderId);
    final QueueOrder currentOrder = _orders![index];

    if (currentOrder.status != QueueOrderStatus.paidReady ||
        currentOrder.paymentStatus != OrderPaymentStatus.confirmed) {
      throw StateError('Seule une commande payée et prête peut être affectée.');
    }

    final QueueOrder updatedOrder = currentOrder.copyWith(
      assignedAgentId: agentId,
      assignedAgentName: agentId == 'AGENT-001' ? 'Koffi Kouassi' : 'Agent',
      assignedByUserId: assignedByUserId,
      assignedAt: DateTime.now(),
      assignmentMode: OrderAssignmentMode.manual,
      assignmentStatus: OrderAssignmentStatus.assigned,
    );
    _orders![index] = updatedOrder;
    _notify();
    return updatedOrder;
  }

  @override
  Stream<List<QueueOrder>> watchAssignedOrders({
    required String agentId,
  }) async* {
    List<QueueOrder> getAssigned() {
      _orders ??= _createInitialOrders();
      final List<QueueOrder> orders = _orders!
          .where((QueueOrder order) {
            return order.assignedAgentId == agentId &&
                order.assignmentStatus != OrderAssignmentStatus.unassigned;
          })
          .toList(growable: false);
      orders.sort((QueueOrder first, QueueOrder second) {
        final DateTime firstDate = first.assignedAt ?? first.createdAt;
        final DateTime secondDate = second.assignedAt ?? second.createdAt;
        return secondDate.compareTo(firstDate);
      });
      return List<QueueOrder>.unmodifiable(orders);
    }

    yield getAssigned();
    await for (final _ in _changes.stream) {
      yield getAssigned();
    }
  }

  @override
  Future<QueueOrder> acceptAgentAssignment({
    required String orderId,
    required String agentId,
  }) async {
    await _delay(250);
    final int index = _findOrderIndex(orderId);
    final QueueOrder currentOrder = _orders![index];
    _verifyPendingAgentAssignment(currentOrder, agentId);

    final QueueOrder updatedOrder = currentOrder.copyWith(
      assignmentStatus: OrderAssignmentStatus.accepted,
    );
    _orders![index] = updatedOrder;
    _notify();
    return updatedOrder;
  }

  @override
  Future<QueueOrder> refuseAgentAssignment({
    required String orderId,
    required String agentId,
    required String reason,
  }) async {
    await _delay(250);
    final String cleanedReason = reason.trim();
    if (cleanedReason.length < 3) {
      throw StateError('Indique un motif de refus plus précis.');
    }
    if (cleanedReason.length > 500) {
      throw StateError('Le motif de refus est trop long.');
    }

    final int index = _findOrderIndex(orderId);
    final QueueOrder currentOrder = _orders![index];
    _verifyPendingAgentAssignment(currentOrder, agentId);

    final QueueOrder updatedOrder = currentOrder.copyWith(
      clearAgentAssignment: true,
      lastAssignmentRefusalReason: cleanedReason,
      lastAssignmentRefusedAt: DateTime.now(),
    );
    _orders![index] = updatedOrder;
    _notify();
    return updatedOrder;
  }

  void _verifyPendingAgentAssignment(QueueOrder order, String agentId) {
    if (order.assignedAgentId != agentId ||
        order.assignmentStatus != OrderAssignmentStatus.assigned) {
      throw StateError('Cette commande ne t’est plus affectée.');
    }
    if (order.status != QueueOrderStatus.paidReady ||
        order.paymentStatus != OrderPaymentStatus.confirmed) {
      throw StateError('Cette commande n’est plus disponible à l’acceptation.');
    }
  }

  @override
  Future<Map<String, int>> fetchActiveAssignmentCounts() async {
    _orders ??= _createInitialOrders();
    final Map<String, int> counts = <String, int>{};
    for (final QueueOrder order in _orders!) {
      final String? agentId = order.assignedAgentId;
      if (agentId == null || agentId.isEmpty) continue;
      if (order.assignmentStatus != OrderAssignmentStatus.assigned &&
          order.assignmentStatus != OrderAssignmentStatus.accepted) {
        continue;
      }
      counts[agentId] = (counts[agentId] ?? 0) + 1;
    }
    return Map<String, int>.unmodifiable(counts);
  }

  @override
  Future<QueueOrder> takeCharge({
    required String orderId,
    required String operatorId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final int index = _findOrderIndex(orderId);
    final QueueOrder currentOrder = _orders![index];

    if (currentOrder.status != QueueOrderStatus.paidReady) {
      throw StateError('Cette commande est déjà prise en charge.');
    }

    final QueueOrder updatedOrder = currentOrder.copyWith(
      status: QueueOrderStatus.inProgress,
      takenByUserId: operatorId,
      takenAt: DateTime.now(),
    );

    _orders![index] = updatedOrder;

    return updatedOrder;
  }

  @override
  Future<QueueOrder> markSuccessful({required String orderId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final int index = _findOrderIndex(orderId);
    final QueueOrder currentOrder = _orders![index];

    _verifyOrderIsInProgress(currentOrder);

    final QueueOrder updatedOrder = currentOrder.copyWith(
      status: QueueOrderStatus.awaitingCustomerConfirmation,
      completedAt: DateTime.now(),
      customerConfirmationStatus: CustomerConfirmationStatus.pending,
    );

    _orders![index] = updatedOrder;

    return updatedOrder;
  }

  @override
  Future<QueueOrder> completeCustomerConfirmation({
    required String orderId,
    required bool messageSent,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final int index = _findOrderIndex(orderId);
    final QueueOrder currentOrder = _orders![index];

    if (currentOrder.status != QueueOrderStatus.awaitingCustomerConfirmation) {
      throw StateError('Cette commande n’attend pas de confirmation client.');
    }

    final QueueOrder updatedOrder = currentOrder.copyWith(
      status: QueueOrderStatus.completed,
      customerConfirmationStatus: messageSent
          ? CustomerConfirmationStatus.sent
          : CustomerConfirmationStatus.skipped,
      customerConfirmationCompletedAt: DateTime.now(),
    );

    _orders![index] = updatedOrder;

    return updatedOrder;
  }

  @override
  Future<QueueOrder> markFailed({
    required String orderId,
    required OrderFailureReason reason,
    String? observation,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final int index = _findOrderIndex(orderId);
    final QueueOrder currentOrder = _orders![index];

    _verifyOrderIsInProgress(currentOrder);

    final QueueOrder updatedOrder = currentOrder.copyWith(
      status: QueueOrderStatus.failed,
      completedAt: DateTime.now(),
      failureReason: reason,
      observation: observation,
    );

    _orders![index] = updatedOrder;

    return updatedOrder;
  }

  @override
  Future<QueueOrder> putOnHold({required String orderId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final int index = _findOrderIndex(orderId);
    final QueueOrder currentOrder = _orders![index];

    _verifyOrderIsInProgress(currentOrder);

    final QueueOrder updatedOrder = currentOrder.copyWith(
      status: QueueOrderStatus.paidReady,
      clearAssignment: true,
    );

    _orders![index] = updatedOrder;

    return updatedOrder;
  }

  int _findOrderIndex(String orderId) {
    _orders ??= _createInitialOrders();

    final int index = _orders!.indexWhere((QueueOrder order) {
      return order.id == orderId;
    });

    if (index == -1) {
      throw StateError('La commande est introuvable.');
    }

    return index;
  }

  void _verifyOrderIsInProgress(QueueOrder order) {
    if (order.status != QueueOrderStatus.inProgress) {
      throw StateError('Cette commande n’est pas en cours de traitement.');
    }
  }

  @override
  Future<QueueOrder> createOrder({required CreateOrderRequest request}) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    _orders ??= _createInitialOrders();

    final DateTime now = DateTime.now();
    final int nextReference = _nextReferenceNumber();

    final QueueOrder order = QueueOrder(
      id: 'order-$nextReference',
      reference: 'ORD-$nextReference',
      source: OrderSource.operatorApp,
      clientName: request.clientName.trim(),
      clientWhatsappPhone: request.clientWhatsappPhone.trim(),
      network: request.network,
      beneficiaryPhone: request.beneficiaryPhone.trim(),
      operationType: request.operationType,
      offerLabel: request.offerLabel.trim(),
      amount: request.amount,
      originalWhatsappMessage: request.originalWhatsappMessage?.trim(),
      internalNotes: request.internalNotes?.trim(),
      createdAt: now,
      paidAt: null,
      paymentRequestSentAt: null,
      paymentReference: null,
      status: QueueOrderStatus.awaitingPayment,
      paymentStatus: OrderPaymentStatus.pending,
      expiresAt: now.add(const Duration(hours: 6)),
    );

    _orders!.insert(0, order);

    return order;
  }

  int _nextReferenceNumber() {
    _orders ??= _createInitialOrders();

    int highestReference = 9822;

    for (final QueueOrder order in _orders!) {
      final List<String> parts = order.reference.split('-');

      if (parts.isEmpty) {
        continue;
      }

      final int? number = int.tryParse(parts.last);

      if (number != null && number > highestReference) {
        highestReference = number;
      }
    }

    return highestReference + 1;
  }

  List<QueueOrder> _createInitialOrders() {
    final DateTime now = DateTime.now();

    const List<OrderOperationType> operationTypes = [
      OrderOperationType.internetSubscription,
      OrderOperationType.unitTransfer,
      OrderOperationType.internetSubscription,
      OrderOperationType.mixedBundle,
      OrderOperationType.callBundle,
      OrderOperationType.internetSubscription,
      OrderOperationType.unitTransfer,
      OrderOperationType.internetSubscription,
      OrderOperationType.mixedBundle,
      OrderOperationType.internetSubscription,
      OrderOperationType.unitTransfer,
      OrderOperationType.callBundle,
      OrderOperationType.internetSubscription,
      OrderOperationType.mixedBundle,
    ];

    const List<MobileNetwork> networks = [
      MobileNetwork.orange,
      MobileNetwork.mtn,
      MobileNetwork.moov,
      MobileNetwork.orange,
      MobileNetwork.mtn,
      MobileNetwork.orange,
      MobileNetwork.moov,
      MobileNetwork.mtn,
      MobileNetwork.orange,
      MobileNetwork.mtn,
      MobileNetwork.orange,
      MobileNetwork.moov,
      MobileNetwork.mtn,
      MobileNetwork.orange,
    ];

    const List<String> clients = [
      'Boutique Akwa - Jean D.',
      'Mariam Koné',
      'Koffi Alex',
      'Awa Traoré',
      'Yao Serge',
      'Jean Kouassi',
      'Grâce Yapi',
      'Serge N’Guessan',
      'Alice Koffi',
      'Moussa Diallo',
      'Fatou Koné',
      'Emma Kouassi',
      'Didier Yao',
      'Boutique Grâce',
    ];

    const List<int> waitingMinutes = [
      6,
      2,
      1,
      8,
      4,
      10,
      3,
      7,
      5,
      12,
      2,
      9,
      3,
      14,
    ];

    const List<String> clientWhatsappPhones = [
      '07 07 11 22 33',
      '05 05 12 34 56',
      '01 01 23 45 67',
      '07 07 28 39 40',
      '05 05 72 83 94',
      '07 07 55 66 77',
      '01 01 43 54 65',
      '05 05 20 30 40',
      '07 07 64 53 42',
      '05 05 87 76 65',
      '07 07 32 43 54',
      '01 01 22 33 44',
      '05 05 35 46 57',
      '07 07 82 73 64',
    ];

    const List<String> phones = [
      '07 78 45 12 90',
      '05 55 12 34 56',
      '01 02 03 04 05',
      '07 17 28 39 40',
      '05 61 72 83 94',
      '07 44 55 66 77',
      '01 32 43 54 65',
      '05 10 20 30 40',
      '07 75 64 53 42',
      '05 98 87 76 65',
      '07 21 32 43 54',
      '01 11 22 33 44',
      '05 24 35 46 57',
      '07 91 82 73 64',
    ];

    const List<String> offers = [
      'Forfait Internet 5Go - 7J',
      'Transfert d’unité',
      'Pass Internet',
      'Forfait mixte',
      'Pass appels',
      'Pass Internet - 5 Go',
      'Transfert d’unité',
      'Pass Internet',
      'Forfait mixte',
      'Pass Internet - Maxi Data',
      'Transfert d’unité',
      'Pass appels',
      'Pass Internet',
      'Forfait mixte',
    ];

    const List<int> amounts = [
      2000,
      5000,
      1500,
      3000,
      1000,
      5000,
      2000,
      1000,
      2500,
      3000,
      1000,
      2000,
      1500,
      5000,
    ];

    return List<QueueOrder>.generate(networks.length, (int index) {
      final DateTime paidAt = now.subtract(
        Duration(minutes: waitingMinutes[index]),
      );

      return QueueOrder(
        id: 'order-${index + 1}',
        reference: 'ORD-${9823 + index}',
        source: OrderSource.operatorApp,
        clientName: clients[index],
        clientWhatsappPhone: clientWhatsappPhones[index],
        network: networks[index],
        beneficiaryPhone: phones[index],
        operationType: operationTypes[index],
        offerLabel: offers[index],
        amount: amounts[index],
        createdAt: paidAt.subtract(const Duration(minutes: 2)),
        paidAt: paidAt,
        paymentConfirmedAt: paidAt,
        status: QueueOrderStatus.paidReady,
        paymentStatus: OrderPaymentStatus.confirmed,
      );
    });
  }
}
