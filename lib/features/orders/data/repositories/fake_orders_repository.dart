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
    await Future<void>.delayed(const Duration(milliseconds: 850));

    _orders ??= _createInitialOrders();

    final int orderIndex = _orders!.indexWhere((QueueOrder order) {
      return order.id == orderId;
    });

    if (orderIndex == -1) {
      throw StateError('La commande demandée est introuvable.');
    }

    final QueueOrder currentOrder = _orders![orderIndex];

    if (currentOrder.status != QueueOrderStatus.paidReady) {
      throw StateError('Cette commande est déjà prise en charge.');
    }

    final QueueOrder updatedOrder = currentOrder.copyWith(
      status: QueueOrderStatus.inProgress,
      takenByUserId: operatorId,
      takenAt: DateTime.now(),
    );

    _orders![orderIndex] = updatedOrder;

    return updatedOrder;
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

    const List<String> phones = [
      '07 08 90 12 34',
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
      'Pass Internet - Maxi Data',
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
