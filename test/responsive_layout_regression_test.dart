import 'package:cabine_flow/app/app.dart';
import 'package:cabine_flow/core/theme/app_theme.dart';
import 'package:cabine_flow/features/agents/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/commissions/data/repositories/fake_commission_repository.dart';
import 'package:cabine_flow/features/finances/presentation/pages/finances_page.dart';
import 'package:cabine_flow/features/finances/presentation/pages/financial_movements_page.dart';
import 'package:cabine_flow/features/finances/presentation/pages/financial_reconciliation_page.dart';
import 'package:cabine_flow/features/refunds/data/repositories/fake_refund_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/presentation/pages/agent_orders_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/orders_page.dart';
import 'package:cabine_flow/features/payments/presentation/pages/payments_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> useCompactPhone(WidgetTester tester) async {
    // Gabarit volontairement plus exigeant que le téléphone de test principal.
    // Il sert de garde-fou contre les RenderFlex overflowed sur petits écrans.
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('connexion reste rendable sur un petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    await tester.pumpWidget(const CabineFlowApp());
    await tester.pump();

    expect(find.text('Bienvenue'), findsOneWidget);
    expect(find.text('Se souvenir de moi'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('liste Commandes Admin ne déborde pas sur un petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    final FakeOrdersRepository ordersRepository = FakeOrdersRepository(
      isTest: true,
    );

    const AppUser admin = AppUser(
      id: 'ADMIN-001',
      name: 'Marc Alex',
      phoneNumber: '0700000000',
      role: UserRole.administrator,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OrdersPage(
          user: admin,
          ordersRepository: ordersRepository,
          agentRepository: FakeAgentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Commandes'), findsOneWidget);
    expect(find.text('À traiter'), findsOneWidget);
    expect(find.text('Filtres'), findsOneWidget);
    expect(find.textContaining('à traiter aujourd'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('liste Paiements Admin ne déborde pas sur un petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    final FakeOrdersRepository ordersRepository = FakeOrdersRepository(
      isTest: true,
    );

    const AppUser admin = AppUser(
      id: 'ADMIN-001',
      name: 'Marc Alex',
      phoneNumber: '0700000000',
      role: UserRole.administrator,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PaymentsPage(
          user: admin,
          ordersRepository: ordersRepository,
          onPaymentConfirmed: () {},
          onOpenOrders: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paiements'), findsOneWidget);
    expect(find.text('Tous'), findsOneWidget);
    expect(find.textContaining('CabineFlow'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hub Finances Admin ne déborde pas sur un petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    final FakeOrdersRepository ordersRepository = FakeOrdersRepository(
      isTest: true,
    );

    const AppUser admin = AppUser(
      id: 'ADMIN-001',
      name: 'Marc Alex',
      phoneNumber: '0700000000',
      role: UserRole.administrator,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FinancesPage(
          user: admin,
          ordersRepository: ordersRepository,
          commissionRepository: FakeCommissionRepository(),
          agentRepository: FakeAgentRepository(),
          onOpenPayments: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finances'), findsOneWidget);
    expect(find.text('Gestion financière'), findsOneWidget);
    expect(find.text('Remboursements'), findsOneWidget);
    expect(find.text('Commissions'), findsOneWidget);
    expect(find.text('Rapprochements'), findsOneWidget);
    expect(find.text('Mouvements'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapprochements financiers restent rendables sur petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    final FakeOrdersRepository ordersRepository = FakeOrdersRepository(isTest: true);
    final FakeRefundRepository refundRepository = FakeRefundRepository();
    addTearDown(refundRepository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FinancialReconciliationPage(
          user: const AppUser(
            id: 'ADMIN-001',
            name: 'Marc Alex',
            phoneNumber: '0700000000',
            role: UserRole.administrator,
          ),
          ordersRepository: ordersRepository,
          refundRepository: refundRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rapprochements'), findsOneWidget);
    expect(find.text('Tous'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('journal des mouvements reste rendable sur petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    final FakeOrdersRepository ordersRepository = FakeOrdersRepository(isTest: true);
    final FakeRefundRepository refundRepository = FakeRefundRepository();
    addTearDown(refundRepository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FinancialMovementsPage(
          ordersRepository: ordersRepository,
          refundRepository: refundRepository,
          commissionRepository: FakeCommissionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mouvements'), findsOneWidget);
    expect(find.text('Entrées'), findsWidgets);
    expect(find.text('Sorties'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('file Agent ne déborde pas sur un petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    final FakeOrdersRepository ordersRepository = FakeOrdersRepository(
      isTest: true,
    );
    final QueueOrder order = (await ordersRepository.fetchPaidQueue()).first;
    await ordersRepository.assignToAgent(
      orderId: order.id,
      agentId: 'AGENT-001',
      assignedByUserId: 'ADMIN-001',
    );

    const AppUser agent = AppUser(
      id: 'AGENT-001',
      name: 'Koffi Kouassi',
      phoneNumber: '0700000001',
      role: UserRole.agent,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AgentOrdersPage(
          user: agent,
          ordersRepository: ordersRepository,
          agentRepository: FakeAgentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PRIORITÉ 1'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
