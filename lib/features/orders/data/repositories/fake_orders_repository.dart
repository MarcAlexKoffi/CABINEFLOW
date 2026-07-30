import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';

class FakeOrdersRepository implements OrdersRepository {
  List<QueueOrder>? _orders;

  @override
  Future<List<QueueOrder>> fetchPaidQueue() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    _orders ??= _createInitialOrders();

    return List<QueueOrder>.unmodifiable(
      _orders!.where((QueueOrder order) {
        return order.status == QueueOrderStatus.paidReady;
      }),
    );
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

  List<QueueOrder> _createInitialOrders() {
    final DateTime now = DateTime.now();

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
      return QueueOrder(
        id: 'order-${index + 1}',
        reference: 'ORD-${9823 + index}',
        clientName: clients[index],
        clientWhatsappPhone: clientWhatsappPhones[index],
        network: networks[index],
        beneficiaryPhone: phones[index],
        offerLabel: offers[index],
        amount: amounts[index],
        paidAt: now.subtract(Duration(minutes: waitingMinutes[index])),
        status: QueueOrderStatus.paidReady,
      );
    });
  }
}
