import 'dart:async';
import 'package:cabine_flow/app/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/app/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/app/domain/entities/auth/app_user.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/domain/repositories/shared_order_queue_repository.dart';
import 'package:cabine_flow/app/modules/agent_ops/controllers/agent_home_view_model.dart';
import 'package:cabine_flow/app/modules/agent_ops/views/agent_home_page.dart';
import 'package:cabine_flow/app/modules/agent_orders/controllers/agent_orders_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const agent = AppUser(
  id: 'AGENT-001',
  name: 'Agent Test',
  phoneNumber: '',
  role: UserRole.agent,
);
QueueOrder order(
  String id, {
  QueueOrderStatus status = QueueOrderStatus.paidReady,
  OrderAssignmentStatus assignment = OrderAssignmentStatus.assigned,
  String owner = 'AGENT-001',
}) => QueueOrder(
  id: id,
  reference: 'CF-$id',
  clientName: 'Client',
  clientWhatsappPhone: '',
  network: MobileNetwork.moov,
  beneficiaryPhone: '',
  operationType: OrderOperationType.callBundle,
  offerLabel: 'Folie',
  amount: 500,
  createdAt: DateTime.utc(2026, 11, 18),
  status: status,
  assignedAgentId: owner,
  assignmentStatus: assignment,
);
AvailableSharedOrder available(String id) => AvailableSharedOrder(
  id: id,
  reference: 'CF-$id',
  zoneId: 'zone',
  network: MobileNetwork.moov,
  offerLabel: 'Folie',
  service: 'callBundle',
  amount: 500,
  beneficiaryMasked: '•• 0018',
  availableAt: DateTime.utc(2026, 11, 18),
  version: 1,
  canAccept: true,
);
SharedQueueSnapshot snapshot(
  List<String> ids, {
  bool enabled = true,
  int revision = 0,
}) => SharedQueueSnapshot(
  orders: ids.map(available).toList(),
  serverNow: DateTime.utc(2026, 11, 18, 9, 0, revision),
  enabled: enabled,
);

class _Orders extends FakeOrdersRepository
    implements SharedOrderQueueRepository {
  _Orders() : super(isTest: true);
  final assignedEvents = StreamController<List<QueueOrder>>.broadcast(
    sync: true,
  );
  final sharedEvents = StreamController<SharedQueueSnapshot>.broadcast(
    sync: true,
  );
  List<QueueOrder> assigned = const [];
  SharedQueueSnapshot shared = snapshot([]);
  int assignedReads = 0, sharedReads = 0;
  Completer<List<QueueOrder>>? pending;
  @override
  Stream<List<QueueOrder>> watchAssignedOrders({required String agentId}) =>
      assignedEvents.stream;
  @override
  Future<List<QueueOrder>> fetchAssignedOrders({
    required String agentId,
  }) async {
    assignedReads++;
    return pending?.future ?? assigned;
  }

  @override
  Stream<SharedQueueSnapshot> watchAvailableOrders({
    SharedQueueCursor? after,
  }) => sharedEvents.stream;
  @override
  Future<SharedQueueSnapshot> fetchAvailableOrders({
    SharedQueueCursor? after,
  }) async {
    sharedReads++;
    return shared;
  }

  @override
  Future<QueueOrder> claimAvailableOrder(AvailableSharedOrder item) =>
      throw UnimplementedError('Home must never claim an order');
  Future<void> close() async {
    await assignedEvents.close();
    await sharedEvents.close();
  }
}

void main() {
  test(
    'home includes the shared queue, deduplicates assigned orders and excludes other agents',
    () async {
      final repo = _Orders();
      final model = AgentHomeViewModel(agentId: agent.id, repository: repo)
        ..start();
      expect(model.hasData, isFalse);
      expect(model.loading, isTrue);
      repo.assignedEvents.add([
        order('assigned'),
        order('assigned'),
        order(
          'active',
          status: QueueOrderStatus.inProgress,
          assignment: OrderAssignmentStatus.accepted,
        ),
        order(
          'done',
          status: QueueOrderStatus.completed,
          assignment: OrderAssignmentStatus.accepted,
        ),
        order('foreign', owner: 'other'),
      ]);
      repo.sharedEvents.add(snapshot(['shared', 'assigned']));
      expect(model.hasData, isTrue);
      expect(model.toAccept, 2);
      expect(model.inProgress, 1);
      expect(model.completed, 1);
      repo.sharedEvents.add(snapshot([], revision: 1));
      expect(model.toAccept, 1);
      model.dispose();
      await repo.close();
    },
  );
  test('home counts personal states exactly like the Orders tab', () async {
    final repo = _Orders();
    final model = AgentHomeViewModel(agentId: agent.id, repository: repo)
      ..start();
    final queue = AgentOrdersViewModel(
      agentId: agent.id,
      ordersRepository: repo,
    );
    await queue.start();
    final rows = [
      order('pending'),
      for (final status in QueueOrderStatus.values)
        order(
          status.name,
          status: status,
          assignment: OrderAssignmentStatus.accepted,
        ),
    ];
    repo.assignedEvents.add(rows);
    repo.sharedEvents.add(snapshot([], enabled: false));
    expect(model.toAccept, queue.toAcceptCount);
    expect(model.inProgress, queue.inProgressCount);
    expect(model.completed, queue.completedCount);
    queue.dispose();
    model.dispose();
    await repo.close();
  });
  test('a claim then completion immediately updates home counts', () async {
    final repo = _Orders();
    final model = AgentHomeViewModel(agentId: agent.id, repository: repo)
      ..start();
    repo.assignedEvents.add([]);
    repo.sharedEvents.add(snapshot(['one']));
    expect(model.toAccept, 1);
    repo.assignedEvents.add([
      order(
        'one',
        status: QueueOrderStatus.inProgress,
        assignment: OrderAssignmentStatus.accepted,
      ),
    ]);
    expect(model.toAccept, 0);
    expect(model.inProgress, 1);
    repo.sharedEvents.add(snapshot([], revision: 1));
    repo.assignedEvents.add([
      order(
        'one',
        status: QueueOrderStatus.completed,
        assignment: OrderAssignmentStatus.accepted,
      ),
    ]);
    expect(model.inProgress, 0);
    expect(model.completed, 1);
    model.dispose();
    await repo.close();
  });

  test(
    'Home uses the canonical total instead of the first page length',
    () async {
      final repo = _Orders();
      final model = AgentHomeViewModel(agentId: agent.id, repository: repo)
        ..start();
      repo.assignedEvents.add([]);
      final page = snapshot(['one']);
      repo.sharedEvents.add(
        SharedQueueSnapshot(
          orders: page.orders,
          serverNow: page.serverNow,
          enabled: true,
          totalCount: 109,
        ),
      );
      expect(model.toAccept, 109);
      model.dispose();
      await repo.close();
    },
  );
  test(
    'refresh queries both real sources and a newer stream event wins',
    () async {
      final repo = _Orders();
      final model = AgentHomeViewModel(agentId: agent.id, repository: repo)
        ..start();
      repo.assignedEvents.add([]);
      repo.sharedEvents.add(snapshot([]));
      repo.assigned = [order('fetched')];
      repo.shared = snapshot(['shared'], revision: 1);
      await model.refresh();
      expect(repo.assignedReads, 1);
      expect(repo.sharedReads, 1);
      expect(model.toAccept, 2);
      repo.pending = Completer();
      final refresh = model.refresh();
      repo.assignedEvents.add([
        order(
          'new',
          status: QueueOrderStatus.inProgress,
          assignment: OrderAssignmentStatus.accepted,
        ),
      ]);
      repo.pending!.complete([order('old')]);
      await refresh;
      expect(model.assignedToAccept, 0);
      expect(model.inProgress, 1);
      model.dispose();
      await repo.close();
    },
  );
  test(
    'read failures preserve known counts with an error and clear denied personal data',
    () async {
      final repo = _Orders();
      final model = AgentHomeViewModel(agentId: agent.id, repository: repo)
        ..start();
      repo.assignedEvents.add([order('one')]);
      repo.sharedEvents.add(snapshot(['shared']));
      repo.assignedEvents.addError(TimeoutException('fixture'));
      expect(model.toAccept, 2);
      expect(model.error, isNotNull);
      repo.assignedEvents.add([order('one')]);
      repo.sharedEvents.addError(TimeoutException('fixture'));
      expect(model.toAccept, 2);
      expect(model.error, isNotNull);
      repo.sharedEvents.add(snapshot([], revision: 1));
      expect(model.error, isNull);
      repo.assignedEvents.addError(
        const PostgrestException(message: 'denied', code: '42501'),
      );
      expect(model.hasData, isFalse);
      expect(model.assignedToAccept, 0);
      model.dispose();
      await repo.close();
    },
  );
  Future<void> mount(
    WidgetTester tester,
    _Orders repo, {
    double width = 390,
    double scale = 1,
    VoidCallback? open,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: AgentHomePage(
          user: agent,
          ordersRepository: repo,
          agentRepository: FakeAgentRepository(),
          onOpenOrders: open ?? () {},
          onOpenHistory: () {},
          onOpenProfile: () {},
          onOpenActivity: () {},
          onOpenCommissions: () {},
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> close(WidgetTester tester, _Orders repo) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.close();
  }

  testWidgets('loading never announces an empty urgent queue', (tester) async {
    final repo = _Orders();
    await mount(tester, repo);
    expect(find.text('Synchronisation de ta file'), findsOneWidget);
    expect(find.text('Aucune commande urgente'), findsNothing);
    expect(find.text('—'), findsNWidgets(3));
    await close(tester, repo);
  });
  testWidgets(
    'the blue priority card updates from shared commands and opens Orders',
    (tester) async {
      final repo = _Orders();
      var opened = 0;
      await mount(tester, repo, open: () => opened++);
      repo.assignedEvents.add([]);
      repo.sharedEvents.add(snapshot(['one', 'two']));
      await tester.pumpAndSettle();
      expect(find.text('2 commandes à prendre'), findsOneWidget);
      expect(find.text('À prendre'), findsOneWidget);
      final card = find.byKey(const ValueKey('agent-priority-card'));
      expect(card, findsOneWidget);
      expect(
        tester
            .widgetList<DecoratedBox>(
              find.descendant(of: card, matching: find.byType(DecoratedBox)),
            )
            .any((w) => (w.decoration as BoxDecoration).gradient != null),
        isTrue,
      );
      await tester.tap(find.text('Voir les commandes'));
      expect(opened, 1);
      repo.sharedEvents.add(snapshot([], revision: 1));
      await tester.pumpAndSettle();
      expect(find.text('Aucune commande urgente'), findsOneWidget);
      await close(tester, repo);
    },
  );
  testWidgets('initial failures show retry instead of a misleading all-clear', (
    tester,
  ) async {
    final repo = _Orders();
    await mount(tester, repo);
    repo.assignedEvents.add([]);
    repo.sharedEvents.addError(TimeoutException('fixture'));
    await tester.pumpAndSettle();
    expect(find.text('Commandes indisponibles'), findsOneWidget);
    expect(find.text('Aucune commande urgente'), findsNothing);
    repo.shared = snapshot(['fetched'], revision: 1);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(repo.assignedReads, 1);
    expect(repo.sharedReads, 1);
    expect(find.text('1 commande à prendre'), findsOneWidget);
    await close(tester, repo);
  });
  for (final scale in [1.0, 1.6]) {
    testWidgets('blue card fits a 320px screen at text scale $scale', (
      tester,
    ) async {
      final repo = _Orders();
      await mount(tester, repo, width: 320, scale: scale);
      repo.assignedEvents.add([order('own')]);
      repo.sharedEvents.add(snapshot(['one', 'two']));
      await tester.pumpAndSettle();
      expect(find.text('3 commandes à prendre'), findsOneWidget);
      // Layout exceptions are checked automatically by the widget test runner.
      await close(tester, repo);
    });
  }
  testWidgets('returning to foreground actually refreshes both queues', (
    tester,
  ) async {
    final repo = _Orders();
    await mount(tester, repo);
    repo.assignedEvents.add([]);
    repo.sharedEvents.add(snapshot([]));
    await tester.pumpAndSettle();
    repo.shared = snapshot(['on-resume'], revision: 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.sharedReads, 1);
    expect(repo.assignedReads, 1);
    expect(find.text('1 commande à prendre'), findsOneWidget);
    await close(tester, repo);
  });
}
