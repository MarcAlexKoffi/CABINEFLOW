import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/create_order_request.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Flux de paiement manuel', () {
    test('une commande confirmée devient paidReady', () async {
      final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);

      final QueueOrder createdOrder = await repository.createOrder(
        request: const CreateOrderRequest(
          clientName: 'Alex',
          clientWhatsappPhone: '07 00 00 00 00',
          network: MobileNetwork.orange,
          beneficiaryPhone: '07 11 22 33 44',
          operationType: OrderOperationType.internetSubscription,
          offerLabel: 'Pass Internet 2 Go',
          amount: 2000,
        ),
      );

      expect(createdOrder.status, QueueOrderStatus.awaitingPayment);

      final QueueOrder linkSentOrder = await repository.markPaymentRequestSent(
        orderId: createdOrder.id,
      );

      expect(linkSentOrder.paymentRequestSentAt, isNotNull);

      final QueueOrder paidOrder = await repository.confirmPayment(
        orderId: createdOrder.id,
        paidAt: DateTime(2026, 7, 30, 23, 15),
        paymentReference: 'w-123abc',
      );

      expect(paidOrder.status, QueueOrderStatus.paidReady);

      expect(paidOrder.paymentReference, 'W-123ABC');

      expect(paidOrder.paidAt, isNotNull);
    });

    test(
      'génère une référence manuelle quand aucune référence Wave n’est saisie',
      () async {
        final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);

        final QueueOrder createdOrder = await repository.createOrder(
          request: const CreateOrderRequest(
            clientName: 'Mariam',
            clientWhatsappPhone: '05 00 00 00 00',
            network: MobileNetwork.mtn,
            beneficiaryPhone: '05 11 22 33 44',
            operationType: OrderOperationType.unitTransfer,
            offerLabel: 'Transfert d’unités',
            amount: 5000,
          ),
        );

        final QueueOrder paidOrder = await repository.confirmPayment(
          orderId: createdOrder.id,
          paidAt: DateTime(2026, 7, 30, 23, 20),
        );

        expect(paidOrder.status, QueueOrderStatus.paidReady);

        expect(paidOrder.paymentReference, startsWith('MAN-'));
      },
    );
  });
}
