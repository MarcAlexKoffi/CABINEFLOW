import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/order_event.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<QueueOrder> assignAndAccept(FakeOrdersRepository repository) async {
    final QueueOrder order = (await repository.fetchPaidQueue()).first;
    await repository.assignToAgent(
      orderId: order.id,
      agentId: 'AGENT-001',
      assignedByUserId: 'ADMIN-001',
    );
    return repository.acceptAgentAssignment(
      orderId: order.id,
      agentId: 'AGENT-001',
    );
  }

  test('9D journalise le cycle agent dans orderEvents', () async {
    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);
    final QueueOrder accepted = await assignAndAccept(repository);
    final QueueOrder started = await repository.startAgentProcessing(
      orderId: accepted.id,
      agentId: 'AGENT-001',
    );
    await repository.saveOrderProof(
      orderId: started.id,
      orderReference: started.reference,
      agentId: 'AGENT-001',
      fileName: 'preuve.jpg',
      mimeType: 'image/jpeg',
      bytes: <int>[1, 2, 3, 4],
    );
    await repository.putAgentOnHold(
      orderId: started.id,
      agentId: 'AGENT-001',
      reason: 'Réseau temporairement indisponible',
    );
    await repository.resumeAgentProcessing(
      orderId: started.id,
      agentId: 'AGENT-001',
    );
    await repository.markAgentSuccessful(
      orderId: started.id,
      agentId: 'AGENT-001',
    );

    final List<OrderEventType> types = repository.debugOrderEvents
        .where((OrderEvent event) => event.orderId == started.id)
        .map((OrderEvent event) => event.type)
        .toList();

    expect(types, <OrderEventType>[
      OrderEventType.assigned,
      OrderEventType.assignmentAccepted,
      OrderEventType.processingStarted,
      OrderEventType.proofAdded,
      OrderEventType.putOnHold,
      OrderEventType.processingResumed,
      OrderEventType.processingSucceeded,
    ]);
    expect(
      repository.debugOrderEvents
          .where((OrderEvent event) => event.actorRole == 'agent')
          .every((OrderEvent event) => event.actorId == 'AGENT-001'),
      isTrue,
    );
  });

  test(
    '9D un autre agent ne peut ni accepter ni traiter la commande',
    () async {
      final FakeOrdersRepository repository = FakeOrdersRepository(
        isTest: true,
      );
      final QueueOrder order = (await repository.fetchPaidQueue()).first;
      await repository.assignToAgent(
        orderId: order.id,
        agentId: 'AGENT-001',
        assignedByUserId: 'ADMIN-001',
      );

      expect(
        repository.acceptAgentAssignment(
          orderId: order.id,
          agentId: 'AGENT-002',
        ),
        throwsStateError,
      );

      final QueueOrder accepted = await repository.acceptAgentAssignment(
        orderId: order.id,
        agentId: 'AGENT-001',
      );

      expect(
        repository.startAgentProcessing(
          orderId: accepted.id,
          agentId: 'AGENT-002',
        ),
        throwsStateError,
      );
    },
  );

  test(
    '9D les actions agent ne modifient aucun champ métier protégé',
    () async {
      final FakeOrdersRepository repository = FakeOrdersRepository(
        isTest: true,
      );
      final QueueOrder original = (await repository.fetchPaidQueue()).first;
      await repository.assignToAgent(
        orderId: original.id,
        agentId: 'AGENT-001',
        assignedByUserId: 'ADMIN-001',
      );
      final QueueOrder accepted = await repository.acceptAgentAssignment(
        orderId: original.id,
        agentId: 'AGENT-001',
      );
      final QueueOrder started = await repository.startAgentProcessing(
        orderId: accepted.id,
        agentId: 'AGENT-001',
      );
      final QueueOrder held = await repository.putAgentOnHold(
        orderId: started.id,
        agentId: 'AGENT-001',
        reason: 'Attente de disponibilité réseau',
      );

      for (final QueueOrder order in <QueueOrder>[accepted, started, held]) {
        expect(order.amount, original.amount);
        expect(order.network, original.network);
        expect(order.operationType, original.operationType);
        expect(order.offerLabel, original.offerLabel);
        expect(order.beneficiaryPhone, original.beneficiaryPhone);
        expect(order.clientName, original.clientName);
        expect(order.paymentStatus, original.paymentStatus);
        expect(order.paymentReference, original.paymentReference);
      }
    },
  );

  test('9D un refus conserve le motif dans le journal', () async {
    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);
    final QueueOrder order = (await repository.fetchPaidQueue()).first;
    await repository.assignToAgent(
      orderId: order.id,
      agentId: 'AGENT-001',
      assignedByUserId: 'ADMIN-001',
    );

    const String reason = 'Capacité insuffisante sur ce réseau';
    await repository.refuseAgentAssignment(
      orderId: order.id,
      agentId: 'AGENT-001',
      reason: reason,
    );

    final OrderEvent refused = repository.debugOrderEvents.lastWhere(
      (OrderEvent event) => event.type == OrderEventType.assignmentRefused,
    );
    expect(refused.actorId, 'AGENT-001');
    expect(refused.actorRole, 'agent');
    expect(refused.metadata['reason'], reason);
  });
}
