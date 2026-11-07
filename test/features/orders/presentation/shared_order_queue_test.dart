import 'dart:async';
import 'package:cabine_flow/core/notifications/izytel_notification_payload.dart';
import 'package:cabine_flow/core/theme/app_theme.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/shared_order_queue_repository.dart';
import 'package:cabine_flow/features/orders/presentation/pages/shared_agent_orders_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/order_supervision_page.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/shared_order_queue_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const agent = AppUser(
  id: 'AGENT-001',
  name: 'Agent Test',
  phoneNumber: '0700000001',
  role: UserRole.agent,
);

class QueueFake extends FakeOrdersRepository
    implements SharedOrderQueueRepository {
  QueueFake() : super(isTest: true);
  final controller = StreamController<SharedQueueSnapshot>.broadcast(
    sync: true,
  );
  late AvailableSharedOrder available;
  late SharedQueueSnapshot snapshot;
  Object? claimError;
  Object? readError;
  int processingCalls = 0;
  Future<void> prepare() async {
    final row = (await fetchPaidQueue()).first;
    available = AvailableSharedOrder(
      id: row.id,
      reference: row.reference,
      zoneId: 'test-zone',
      network: row.network,
      offerLabel: row.offerLabel,
      service: row.operationType.name,
      amount: row.amount,
      beneficiaryMasked: '•• •• •• 0018',
      availableAt: DateTime.utc(2026, 11, 6, 9, 40),
      version: 0,
      canAccept: true,
    );
    snapshot = SharedQueueSnapshot(
      orders: [available],
      serverNow: DateTime.utc(2026, 11, 6, 9, 42),
      enabled: true,
    );
  }

  @override
  Future<SharedQueueSnapshot> fetchAvailableOrders() async {
    if (readError != null) throw readError!;
    return snapshot;
  }

  @override
  Stream<SharedQueueSnapshot> watchAvailableOrders() async* {
    yield await fetchAvailableOrders();
    yield* controller.stream;
  }

  @override
  Future<QueueOrder> claimAvailableOrder(AvailableSharedOrder order) async {
    if (claimError != null) throw claimError!;
    await assignToAgent(
      orderId: order.id,
      agentId: agent.id,
      assignedByUserId: agent.id,
    );
    return acceptAgentAssignment(orderId: order.id, agentId: agent.id);
  }

  @override
  Future<QueueOrder> startAgentProcessing({
    required String orderId,
    required String agentId,
  }) {
    processingCalls++;
    return super.startAgentProcessing(orderId: orderId, agentId: agentId);
  }
}

class SupervisionFake implements OrderSupervisionRepository {
  final now = DateTime.utc(2026, 11, 6, 9, 42);
  @override
  Future<OrderSupervisionSnapshot> fetchSupervision() async =>
      OrderSupervisionSnapshot(
        serverNow: now,
        orders: [
          {
            'order_id': 'test-order',
            'order_reference': 'TEST-18',
            'assigned_agent_name': 'Agent Test',
            'amount': 1000,
            'offer_label': 'Internet',
            'assignment_state': 'accepted',
            'order_status': 'inProgress',
            'accepted_at': DateTime.utc(2026, 11, 6, 9, 36).toIso8601String(),
            'is_overdue': true,
          },
        ],
        alerts: [
          {
            'order_id': 'test-order',
            'agent_name': 'Agent Test',
            'state': 'active',
            'accepted_at': DateTime.utc(2026, 11, 6, 9, 36).toIso8601String(),
          },
        ],
      );
  @override
  Stream<OrderSupervisionSnapshot> watchSupervision() async* {
    yield await fetchSupervision();
  }
}

class UnavailableSupervisionFake extends SupervisionFake {
  @override
  Future<OrderSupervisionSnapshot> fetchSupervision() async =>
      throw StateError('backend unavailable');
}

void main() {
  testWidgets(
    'both Agent tabs reuse one existing header and preserve personal controls',
    (tester) async {
      final repo = QueueFake();
      await repo.prepare();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SharedAgentOrdersPage(
            user: agent,
            ordersRepository: repo,
            sharedRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Bonjour'), findsOneWidget);
      expect(find.text('Espace Agent'), findsNothing);
      await tester.tap(find.text('Mes commandes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bonjour'), findsOneWidget);
      expect(find.byTooltip('Afficher une autre file'), findsOneWidget);
      await tester.tap(find.text('À prendre'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bonjour'), findsOneWidget);
      expect(find.text('Accepter et traiter'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await repo.controller.close();
    },
  );

  testWidgets(
    'an unavailable Agent queue never claims to be empty and can recover',
    (tester) async {
      final repo = QueueFake();
      await repo.prepare();
      repo.readError = StateError('backend unavailable');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SharedAgentOrdersPage(
            user: agent,
            ordersRepository: repo,
            sharedRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('La file est indisponible'), findsOneWidget);
      expect(find.text('Tout est à jour'), findsNothing);
      expect(find.text('Aucune commande à prendre'), findsNothing);
      repo.readError = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Accepter et traiter'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await repo.controller.close();
    },
  );

  testWidgets(
    'a disabled shared queue explains the state and links to personal orders',
    (tester) async {
      final repo = QueueFake();
      await repo.prepare();
      repo.snapshot = SharedQueueSnapshot(
        orders: const [],
        serverNow: repo.snapshot.serverNow,
        enabled: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SharedAgentOrdersPage(
            user: agent,
            ordersRepository: repo,
            sharedRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('La file partagée sera bientôt disponible'),
        findsOneWidget,
      );
      expect(find.text('Aucune commande à prendre'), findsNothing);
      await tester.tap(find.text('Voir mes commandes'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Afficher une autre file'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await repo.controller.close();
    },
  );

  testWidgets(
    'an unavailable supervision does not display a false empty state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: OrderSupervisionPage(
            user: const AppUser(
              id: 'm1',
              name: 'Manager',
              phoneNumber: '0700000002',
              role: UserRole.manager,
            ),
            repository: UnavailableSupervisionFake(),
            historyRepository: FakeOrdersRepository(isTest: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Le suivi est indisponible'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Aucune commande dans cet état'), findsNothing);
      expect(find.text('Toutes'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'a failed refresh retains rows but disables stale acceptance until a successful read',
    () async {
      final repo = QueueFake();
      await repo.prepare();
      final vm = SharedOrderQueueViewModel(repo)..start();
      await Future<void>.delayed(Duration.zero);
      expect(vm.canAct, isTrue);
      expect(vm.orders.length, 1);
      repo.controller.addError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
      expect(vm.orders.length, 1);
      expect(vm.canAct, isFalse);
      expect(await vm.claim(repo.available), isNull);
      await vm.refresh();
      expect(vm.canAct, isTrue);
      vm.dispose();
      await repo.controller.close();
    },
  );
  test(
    'a server concurrency conflict removes only the taken row and remains explicit',
    () async {
      final repo = QueueFake();
      await repo.prepare();
      repo.claimError = const PostgrestException(
        message: 'ORDER_ALREADY_TAKEN',
      );
      final vm = SharedOrderQueueViewModel(repo)..start();
      await Future<void>.delayed(Duration.zero);
      expect(await vm.claim(repo.available), isNull);
      expect(vm.orders, isEmpty);
      expect(vm.errorMessage, contains('un autre Agent'));
      vm.dispose();
      await repo.controller.close();
    },
  );
  test(
    'a lost response is never fabricated as a successful acceptance',
    () async {
      final repo = QueueFake();
      await repo.prepare();
      repo.claimError = TimeoutException('response lost');
      final vm = SharedOrderQueueViewModel(repo)..start();
      await Future<void>.delayed(Duration.zero);
      expect(await vm.claim(repo.available), isNull);
      expect(vm.orders.length, 1);
      expect(vm.fresh, isFalse);
      vm.dispose();
      await repo.controller.close();
    },
  );
  for (final (width, scale) in [(320.0, 1.0), (390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'shared queue at width $width and text scale $scale: accepted order opens without starting telecom or processing',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = QueueFake();
        await repo.prepare();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SharedAgentOrdersPage(
                user: agent,
                ordersRepository: repo,
                sharedRepository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('À prendre'), findsOneWidget);
        expect(find.text('Mes commandes'), findsOneWidget);
        await tester.ensureVisible(find.text('Accepter et traiter'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Accepter et traiter'));
        await tester.pumpAndSettle();
        expect(repo.processingCalls, 0);
        expect(find.text('Détail commande'), findsOneWidget);
        expect(find.text('Démarrer le traitement'), findsOneWidget);
        final claimed = (await repo.fetchAssignedOrders(
          agentId: agent.id,
        )).first;
        expect(claimed.status, QueueOrderStatus.paidReady);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('À prendre'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
        await repo.controller.close();
      },
    );
  }
  testWidgets(
    'an available-order notification restores the shared tab after the personal tab',
    (tester) async {
      final repo = QueueFake();
      await repo.prepare();
      final request = ValueNotifier<IzyTelNotificationPayload?>(null);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SharedAgentOrdersPage(
              user: agent,
              ordersRepository: repo,
              sharedRepository: repo,
              notificationOrderRequest: request,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mes commandes'));
      await tester.pumpAndSettle();
      expect(find.text('Accepter et traiter'), findsNothing);
      request.value = const IzyTelNotificationPayload(
        type: 'order_available',
        route: 'shared_queue',
        orderId: 'test-order',
      );
      await tester.pumpAndSettle();
      expect(find.text('Accepter et traiter'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await repo.controller.close();
      request.dispose();
    },
  );
  for (final (width, scale) in [(320.0, 1.0), (1024.0, 1.0), (768.0, 2.0)]) {
    testWidgets(
      'manager supervision at width $width and text scale $scale exposes durable alerts',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const manager = AppUser(
          id: 'm1',
          name: 'Manager Test',
          phoneNumber: '0700000002',
          role: UserRole.manager,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: OrderSupervisionPage(
              user: manager,
              repository: SupervisionFake(),
              historyRepository: FakeOrdersRepository(isTest: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('En retard'), findsWidgets);
        await tester.tap(find.text('Voir les alertes'));
        await tester.pumpAndSettle();
        expect(find.text('Délai dépassé'), findsOneWidget);
        expect(find.text('Ouvrir la commande →'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
