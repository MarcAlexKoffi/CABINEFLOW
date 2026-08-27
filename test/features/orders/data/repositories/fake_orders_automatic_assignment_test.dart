import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/create_order_request.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'un paiement confirmé entre dans la file automatique puis peut être réclamé',
    () async {
      final FakeOrdersRepository repository = FakeOrdersRepository(
        isTest: true,
      );
      final QueueOrder created = await repository.createOrder(
        request: const CreateOrderRequest(
          clientName: 'Client',
          clientWhatsappPhone: '0700000000',
          network: MobileNetwork.mtn,
          beneficiaryPhone: '0500000000',
          operationType: OrderOperationType.unitTransfer,
          offerLabel: 'Transfert',
          amount: 3000,
        ),
      );
      await repository.confirmPayment(
        orderId: created.id,
        paidAt: DateTime(2026, 8, 26, 10),
        paymentReference: 'PAY-001',
      );

      final queue = await repository.watchAutomaticAssignmentQueue().first;
      expect(queue, hasLength(1));
      expect(queue.single.orderId, created.id);

      final claimed = await repository.claimAutomaticQueueItem(
        item: queue.single,
        agentId: 'AGENT-001',
      );
      expect(claimed, isTrue);

      final assigned = await repository
          .watchAssignedOrders(agentId: 'AGENT-001')
          .first;
      expect(assigned.single.assignmentMode, OrderAssignmentMode.automatic);
      expect(assigned.single.assignmentStatus, OrderAssignmentStatus.assigned);
      expect(await repository.watchAutomaticAssignmentQueue().first, isEmpty);
    },
  );

  test(
    'un refus remet la commande en file et exclut le dernier agent',
    () async {
      final FakeOrdersRepository repository = FakeOrdersRepository(
        isTest: true,
      );
      final QueueOrder created = await repository.createOrder(
        request: const CreateOrderRequest(
          clientName: 'Client',
          clientWhatsappPhone: '0700000000',
          network: MobileNetwork.orange,
          beneficiaryPhone: '0700000001',
          operationType: OrderOperationType.unitTransfer,
          offerLabel: 'Transfert',
          amount: 1000,
        ),
      );
      await repository.confirmPayment(
        orderId: created.id,
        paidAt: DateTime(2026, 8, 26, 10),
        paymentReference: 'PAY-002',
      );
      final firstQueue = await repository.watchAutomaticAssignmentQueue().first;
      await repository.claimAutomaticQueueItem(
        item: firstQueue.single,
        agentId: 'AGENT-001',
      );
      final assigned = await repository
          .watchAssignedOrders(agentId: 'AGENT-001')
          .first;
      await repository.refuseAgentAssignment(
        orderId: assigned.single.id,
        agentId: 'AGENT-001',
        reason: 'Solde momentanément insuffisant',
      );

      final queue = await repository.watchAutomaticAssignmentQueue().first;
      expect(queue, hasLength(1));
      expect(queue.single.lastRefusedAgentId, 'AGENT-001');
      expect(
        await repository.claimAutomaticQueueItem(
          item: queue.single,
          agentId: 'AGENT-001',
        ),
        isFalse,
      );
      expect(
        await repository.claimAutomaticQueueItem(
          item: queue.single,
          agentId: 'AGENT-002',
        ),
        isTrue,
      );
    },
  );

  test(
    'le backlog paidReady non affecté est remis dans la file automatique',
    () async {
      final FakeOrdersRepository repository = FakeOrdersRepository(
        isTest: true,
      );

      await repository.synchronizeAutomaticAssignmentBacklog();

      final queue = await repository.watchAutomaticAssignmentQueue().first;
      expect(queue, isNotEmpty);
      expect(queue.every((item) => item.amount > 0), isTrue);
    },
  );

  test(
    'une affectation manuelle retire la commande de la file automatique',
    () async {
      final FakeOrdersRepository repository = FakeOrdersRepository(
        isTest: true,
      );
      final QueueOrder created = await repository.createOrder(
        request: const CreateOrderRequest(
          clientName: 'Client',
          clientWhatsappPhone: '0700000000',
          network: MobileNetwork.moov,
          beneficiaryPhone: '0100000000',
          operationType: OrderOperationType.unitTransfer,
          offerLabel: 'Transfert',
          amount: 1500,
        ),
      );
      await repository.confirmPayment(
        orderId: created.id,
        paidAt: DateTime(2026, 8, 26, 11),
        paymentReference: 'PAY-004',
      );

      await repository.assignToAgent(
        orderId: created.id,
        agentId: 'AGENT-001',
        assignedByUserId: 'ADMIN-001',
      );

      expect(await repository.watchAutomaticAssignmentQueue().first, isEmpty);
    },
  );
}
