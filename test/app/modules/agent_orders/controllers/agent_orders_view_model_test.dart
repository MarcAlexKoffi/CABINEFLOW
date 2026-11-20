import 'dart:async';

import 'package:cabine_flow/app/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/app/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/modules/agent_orders/controllers/agent_orders_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _IneligibleOrdersRepository extends FakeOrdersRepository {
  _IneligibleOrdersRepository() : super(isTest: true);

  int acceptCalls = 0;

  @override
  Future<QueueOrder> acceptAgentAssignment({
    required String orderId,
    required String agentId,
  }) async {
    acceptCalls++;
    throw const PostgrestException(
      message: 'AGENT_NOT_ELIGIBLE_CURRENT_STATE',
      code: 'P0001',
    );
  }
}

class _FilterOrdersRepository extends FakeOrdersRepository {
  _FilterOrdersRepository(this.orders) : super(isTest: true);

  List<QueueOrder> orders;
  final changes = StreamController<List<QueueOrder>>.broadcast();

  @override
  Future<List<QueueOrder>> fetchAssignedOrders({
    required String agentId,
  }) async => orders;

  @override
  Stream<List<QueueOrder>> watchAssignedOrders({
    required String agentId,
  }) async* {
    yield orders;
    yield* changes.stream;
  }

  void emit(List<QueueOrder> value) {
    orders = value;
    changes.add(value);
  }
}

void main() {
  test(
    'filtre automatique En cours puis À accepter puis Terminées et choix manuel conservé',
    () async {
      final templates = await FakeOrdersRepository(
        isTest: true,
      ).fetchPaidQueue();
      final completed = templates.first.copyWith(
        assignedAgentId: 'AGENT-001',
        assignmentStatus: OrderAssignmentStatus.accepted,
        status: QueueOrderStatus.completed,
      );
      final assigned = templates[1].copyWith(
        assignedAgentId: 'AGENT-001',
        assignmentStatus: OrderAssignmentStatus.assigned,
      );
      final active = assigned.copyWith(
        assignmentStatus: OrderAssignmentStatus.accepted,
        status: QueueOrderStatus.inProgress,
      );
      final repository = _FilterOrdersRepository([completed, active]);
      final viewModel = AgentOrdersViewModel(
        agentId: 'AGENT-001',
        ordersRepository: repository,
      );
      addTearDown(() async {
        viewModel.dispose();
        await repository.changes.close();
      });
      await viewModel.start();
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.completedCount, 1);
      expect(viewModel.selectedTab, AgentOrdersTab.inProgress);
      expect(viewModel.visibleOrders.single.id, active.id);

      repository.emit([completed, assigned]);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.selectedTab, AgentOrdersTab.toAccept);
      expect(viewModel.visibleOrders.single.id, assigned.id);

      repository.emit([completed]);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.selectedTab, AgentOrdersTab.completed);
      expect(viewModel.visibleOrders.single.id, completed.id);

      repository.emit([]);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.selectedTab, AgentOrdersTab.completed);
      expect(viewModel.visibleOrders, isEmpty);

      repository.emit([completed, assigned]);
      await Future<void>.delayed(Duration.zero);

      viewModel.selectTab(AgentOrdersTab.completed);
      await viewModel.refresh();
      expect(viewModel.selectedTab, AgentOrdersTab.completed);
      expect(viewModel.visibleOrders.single.id, completed.id);

      viewModel.selectTab(AgentOrdersTab.inProgress);
      expect(viewModel.visibleOrders, isEmpty);
      repository.emit([completed, active]);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.selectedTab, AgentOrdersTab.inProgress);
      expect(viewModel.visibleOrders.single.id, active.id);

      repository.emit([
        completed,
        active.copyWith(status: QueueOrderStatus.completed),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.selectedTab, AgentOrdersTab.inProgress);
      expect(viewModel.visibleOrders, isEmpty);
    },
  );

  test(
    'a territorial server refusal explains the zone without retrying or hiding the order',
    () async {
      final repository = _IneligibleOrdersRepository();
      final order = (await repository.fetchPaidQueue()).first;
      await repository.assignToAgent(
        orderId: order.id,
        agentId: 'AGENT-001',
        assignedByUserId: 'ADMIN-001',
      );
      final viewModel = AgentOrdersViewModel(
        agentId: 'AGENT-001',
        ordersRepository: repository,
        agentRepository: FakeAgentRepository(),
      );
      await viewModel.start();
      await Future<void>.delayed(Duration.zero);

      final assigned = viewModel.toAcceptOrders.single.copyWith(
        zoneId: 'outside-agent-zone',
      );
      expect(await viewModel.accept(assigned), isFalse);
      expect(viewModel.errorMessage, contains('zone hors de ton périmètre'));
      expect(
        viewModel.errorMessage,
        isNot(contains('Actualise puis réessaie')),
      );
      expect(viewModel.toAcceptCount, 1);
      expect(repository.acceptCalls, 1);
      viewModel.dispose();
    },
  );

  test(
    'a server eligibility refusal remains explicit without a loaded profile',
    () async {
      final repository = _IneligibleOrdersRepository();
      final order = (await repository.fetchPaidQueue()).first;
      await repository.assignToAgent(
        orderId: order.id,
        agentId: 'AGENT-001',
        assignedByUserId: 'ADMIN-001',
      );
      final viewModel = AgentOrdersViewModel(
        agentId: 'AGENT-001',
        ordersRepository: repository,
      );
      await viewModel.start();
      await Future<void>.delayed(Duration.zero);
      expect(await viewModel.accept(viewModel.toAcceptOrders.single), isFalse);
      expect(
        viewModel.errorMessage,
        contains('zone, la capacité réservée et les quotas'),
      );
      expect(repository.acceptCalls, 1);
      viewModel.dispose();
    },
  );

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

  test('réussite affiche Terminées après la dernière commande', () async {
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
    expect(viewModel.selectedTab, AgentOrdersTab.completed);
    expect(viewModel.visibleOrders.single.id, started.id);
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
