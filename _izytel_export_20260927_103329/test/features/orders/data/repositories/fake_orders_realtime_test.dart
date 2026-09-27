import 'dart:async';

import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'paiements et file payée se mettent à jour après confirmation',
    () async {
      final FakeOrdersRepository repository = FakeOrdersRepository(
        isTest: true,
      );
      final StreamIterator<List<QueueOrder>> payments = StreamIterator(
        repository.watchPaymentTrackingOrders(),
      );
      final StreamIterator<List<QueueOrder>> paidQueue = StreamIterator(
        repository.watchPaidQueue(),
      );

      expect(await payments.moveNext(), isTrue);
      expect(await paidQueue.moveNext(), isTrue);

      final QueueOrder candidate = payments.current.firstWhere(
        (QueueOrder order) =>
            order.paymentStatus != OrderPaymentStatus.confirmed &&
            (order.status == QueueOrderStatus.awaitingPayment ||
                order.status == QueueOrderStatus.paymentToVerify ||
                order.hasPaymentToReviewAfterExpiration),
      );

      final Future<bool> nextPaymentEmission = payments.moveNext();
      final Future<bool> nextQueueEmission = paidQueue.moveNext();
      await Future<void>.delayed(Duration.zero);

      await repository.confirmPayment(
        orderId: candidate.id,
        paidAt: DateTime(2026, 8, 25, 20, 0),
        paymentReference: 'WAVE-TEST-001',
      );

      expect(await nextPaymentEmission, isTrue);
      expect(
        payments.current
            .singleWhere((QueueOrder order) => order.id == candidate.id)
            .paymentStatus,
        OrderPaymentStatus.confirmed,
      );

      expect(await nextQueueEmission, isTrue);
      expect(
        paidQueue.current.any((QueueOrder order) => order.id == candidate.id),
        isTrue,
      );

      await payments.cancel();
      await paidQueue.cancel();
    },
  );

  test('historique temps réel reflète une affectation', () async {
    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);
    final StreamIterator<List<QueueOrder>> history = StreamIterator(
      repository.watchOrderHistory(),
    );

    expect(await history.moveNext(), isTrue);
    final QueueOrder paid = history.current.firstWhere(
      (QueueOrder order) =>
          order.status == QueueOrderStatus.paidReady &&
          order.paymentStatus == OrderPaymentStatus.confirmed,
    );

    final Future<bool> nextHistoryEmission = history.moveNext();
    await Future<void>.delayed(Duration.zero);

    await repository.assignToAgent(
      orderId: paid.id,
      agentId: 'AGENT-001',
      assignedByUserId: 'ADMIN-001',
    );

    expect(await nextHistoryEmission, isTrue);
    final QueueOrder updated = history.current.singleWhere(
      (QueueOrder order) => order.id == paid.id,
    );
    expect(updated.assignedAgentId, 'AGENT-001');
    expect(updated.assignmentStatus, OrderAssignmentStatus.assigned);

    await history.cancel();
  });
}
