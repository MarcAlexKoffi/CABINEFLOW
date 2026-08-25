import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('affecte manuellement une commande payée à un agent', () async {
    final FakeOrdersRepository repository = FakeOrdersRepository();
    final List<QueueOrder> queue = await repository.fetchPaidQueue();
    final QueueOrder order = queue.first;

    final QueueOrder updated = await repository.assignToAgent(
      orderId: order.id,
      agentId: 'AGENT-001',
      assignedByUserId: 'ADMIN-001',
    );

    expect(updated.assignedAgentId, 'AGENT-001');
    expect(updated.assignedAgentName, 'Koffi Kouassi');
    expect(updated.assignmentMode, OrderAssignmentMode.manual);
    expect(updated.assignmentStatus, OrderAssignmentStatus.assigned);
    expect(updated.assignedAt, isNotNull);

    final Map<String, int> counts = await repository
        .fetchActiveAssignmentCounts();
    expect(counts['AGENT-001'], 1);
  });

  test('agent accepte uniquement une commande qui lui est affectée', () async {
    final FakeOrdersRepository repository = FakeOrdersRepository();
    final QueueOrder order = (await repository.fetchPaidQueue()).first;
    await repository.assignToAgent(
      orderId: order.id,
      agentId: 'AGENT-001',
      assignedByUserId: 'ADMIN-001',
    );

    final QueueOrder accepted = await repository.acceptAgentAssignment(
      orderId: order.id,
      agentId: 'AGENT-001',
    );

    expect(accepted.assignedAgentId, 'AGENT-001');
    expect(accepted.assignmentStatus, OrderAssignmentStatus.accepted);
    expect(
      repository.acceptAgentAssignment(orderId: order.id, agentId: 'AGENT-001'),
      throwsStateError,
    );
  });

  test('refus remet la commande dans le circuit de réaffectation', () async {
    final FakeOrdersRepository repository = FakeOrdersRepository();
    final QueueOrder order = (await repository.fetchPaidQueue()).first;
    await repository.assignToAgent(
      orderId: order.id,
      agentId: 'AGENT-001',
      assignedByUserId: 'ADMIN-001',
    );

    final QueueOrder refused = await repository.refuseAgentAssignment(
      orderId: order.id,
      agentId: 'AGENT-001',
      reason: 'Réseau indisponible temporairement',
    );

    expect(refused.assignedAgentId, isNull);
    expect(refused.assignmentStatus, OrderAssignmentStatus.unassigned);
    expect(
      refused.lastAssignmentRefusalReason,
      'Réseau indisponible temporairement',
    );
    expect(refused.lastAssignmentRefusedAt, isNotNull);
    expect(
      (await repository.fetchActiveAssignmentCounts())['AGENT-001'],
      isNull,
    );
  });
}
