import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<QueueOrder> acceptedOrder(FakeOrdersRepository repository) async {
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

  test('agent démarre puis met en attente et reprend une commande', () async {
    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);
    final QueueOrder accepted = await acceptedOrder(repository);

    final QueueOrder started = await repository.startAgentProcessing(
      orderId: accepted.id,
      agentId: 'AGENT-001',
    );
    expect(started.status, QueueOrderStatus.inProgress);
    expect(started.takenByUserId, 'AGENT-001');
    expect(started.takenAt, isNotNull);

    final QueueOrder held = await repository.putAgentOnHold(
      orderId: accepted.id,
      agentId: 'AGENT-001',
      reason: 'Réseau momentanément indisponible',
    );
    expect(held.status, QueueOrderStatus.onHold);
    expect(held.lastHoldReason, 'Réseau momentanément indisponible');
    expect(held.lastHeldAt, isNotNull);

    final QueueOrder resumed = await repository.resumeAgentProcessing(
      orderId: accepted.id,
      agentId: 'AGENT-001',
    );
    expect(resumed.status, QueueOrderStatus.inProgress);
    expect(resumed.lastResumedAt, isNotNull);
  });

  test('une réussite exige une preuve puis clôt le travail agent', () async {
    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);
    final QueueOrder accepted = await acceptedOrder(repository);
    final QueueOrder started = await repository.startAgentProcessing(
      orderId: accepted.id,
      agentId: 'AGENT-001',
    );

    expect(
      repository.markAgentSuccessful(orderId: started.id, agentId: 'AGENT-001'),
      throwsStateError,
    );

    await repository.saveOrderProof(
      orderId: started.id,
      orderReference: started.reference,
      agentId: 'AGENT-001',
      fileName: 'preuve.jpg',
      mimeType: 'image/jpeg',
      bytes: <int>[1, 2, 3, 4],
    );

    final QueueOrder success = await repository.markAgentSuccessful(
      orderId: started.id,
      agentId: 'AGENT-001',
    );
    expect(success.status, QueueOrderStatus.completed);
    expect(success.completedAt, isNotNull);
  });

  test('un échec clôt directement le travail de l’agent', () async {
    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);
    final QueueOrder accepted = await acceptedOrder(repository);
    final QueueOrder started = await repository.startAgentProcessing(
      orderId: accepted.id,
      agentId: 'AGENT-001',
    );

    final QueueOrder failed = await repository.markAgentFailed(
      orderId: started.id,
      agentId: 'AGENT-001',
      reason: OrderFailureReason.networkUnavailable,
      observation: 'Incident confirmé sur le réseau',
    );

    expect(failed.status, QueueOrderStatus.failed);
    expect(failed.failureReason, OrderFailureReason.networkUnavailable);
    expect(failed.completedAt, isNotNull);
  });
}
