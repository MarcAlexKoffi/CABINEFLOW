import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/agent_orders_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ne charge que les commandes affectées à l’agent', () async {
    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);
    final List<QueueOrder> queue = await repository.fetchPaidQueue();
    await repository.assignToAgent(
      orderId: queue[0].id,
      agentId: 'AGENT-001',
      assignedByUserId: 'ADMIN-001',
    );
    await repository.assignToAgent(
      orderId: queue[1].id,
      agentId: 'AGENT-002',
      assignedByUserId: 'ADMIN-001',
    );

    final AgentOrdersViewModel viewModel = AgentOrdersViewModel(
      agentId: 'AGENT-001',
      ordersRepository: repository,
    );
    await viewModel.start();
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.toAcceptCount, 1);
    expect(viewModel.toAcceptOrders.single.assignedAgentId, 'AGENT-001');
    viewModel.dispose();
  });

  test('accepter déplace la commande vers En cours', () async {
    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);
    final QueueOrder order = (await repository.fetchPaidQueue()).first;
    await repository.assignToAgent(
      orderId: order.id,
      agentId: 'AGENT-001',
      assignedByUserId: 'ADMIN-001',
    );

    final AgentOrdersViewModel viewModel = AgentOrdersViewModel(
      agentId: 'AGENT-001',
      ordersRepository: repository,
    );
    await viewModel.start();
    await Future<void>.delayed(Duration.zero);

    expect(await viewModel.accept(viewModel.toAcceptOrders.single), isTrue);
    expect(viewModel.toAcceptCount, 0);
    expect(viewModel.inProgressCount, 1);
    expect(viewModel.selectedTab, AgentOrdersTab.inProgress);
    viewModel.dispose();
  });

  test('refuser retire la commande de Mes commandes', () async {
    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);
    final QueueOrder order = (await repository.fetchPaidQueue()).first;
    await repository.assignToAgent(
      orderId: order.id,
      agentId: 'AGENT-001',
      assignedByUserId: 'ADMIN-001',
    );

    final AgentOrdersViewModel viewModel = AgentOrdersViewModel(
      agentId: 'AGENT-001',
      ordersRepository: repository,
    );
    await viewModel.start();
    await Future<void>.delayed(Duration.zero);

    expect(
      await viewModel.refuse(
        viewModel.toAcceptOrders.single,
        'Capacité insuffisante pour cette opération',
      ),
      isTrue,
    );
    expect(viewModel.toAcceptCount, 0);
    expect(viewModel.inProgressCount, 0);
    viewModel.dispose();
  });

  test('réussite revient vers le prochain travail à traiter', () async {
    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);
    final QueueOrder order = (await repository.fetchPaidQueue()).first;
    await repository.assignToAgent(
      orderId: order.id,
      agentId: 'AGENT-001',
      assignedByUserId: 'ADMIN-001',
    );

    final AgentOrdersViewModel viewModel = AgentOrdersViewModel(
      agentId: 'AGENT-001',
      ordersRepository: repository,
    );
    await viewModel.start();
    await Future<void>.delayed(Duration.zero);

    expect(await viewModel.accept(viewModel.toAcceptOrders.single), isTrue);
    final QueueOrder accepted = viewModel.inProgressOrders.single;
    expect(await viewModel.startProcessing(accepted), isTrue);
    final QueueOrder started = viewModel.inProgressOrders.single;

    final proof = await viewModel.saveProof(
      order: started,
      fileName: 'preuve.jpg',
      mimeType: 'image/jpeg',
      bytes: <int>[1, 2, 3],
    );
    expect(proof, isNotNull);
    expect(await viewModel.markSuccessful(started), isTrue);
    expect(viewModel.completedCount, 1);
    expect(viewModel.selectedTab, AgentOrdersTab.toAccept);
    viewModel.dispose();
  });

  test(
    'réussite reste sur En cours quand une autre commande est active',
    () async {
      final FakeOrdersRepository repository = FakeOrdersRepository(
        isTest: true,
      );
      final List<QueueOrder> queue = await repository.fetchPaidQueue();
      for (final QueueOrder order in queue.take(2)) {
        await repository.assignToAgent(
          orderId: order.id,
          agentId: 'AGENT-001',
          assignedByUserId: 'ADMIN-001',
        );
      }

      final AgentOrdersViewModel viewModel = AgentOrdersViewModel(
        agentId: 'AGENT-001',
        ordersRepository: repository,
      );
      await viewModel.start();
      await Future<void>.delayed(Duration.zero);

      final QueueOrder first = viewModel.toAcceptOrders.first;
      expect(await viewModel.accept(first), isTrue);
      final QueueOrder acceptedFirst = viewModel.orderById(first.id)!;
      expect(await viewModel.startProcessing(acceptedFirst), isTrue);

      final QueueOrder second = viewModel.toAcceptOrders.first;
      expect(await viewModel.accept(second), isTrue);
      final QueueOrder acceptedSecond = viewModel.orderById(second.id)!;
      expect(await viewModel.startProcessing(acceptedSecond), isTrue);

      final QueueOrder processingFirst = viewModel.orderById(first.id)!;
      expect(
        await viewModel.saveProof(
          order: processingFirst,
          fileName: 'preuve.jpg',
          mimeType: 'image/jpeg',
          bytes: <int>[1, 2, 3],
        ),
        isNotNull,
      );
      expect(await viewModel.markSuccessful(processingFirst), isTrue);
      expect(viewModel.inProgressCount, 1);
      expect(viewModel.selectedTab, AgentOrdersTab.inProgress);
      viewModel.dispose();
    },
  );
}
