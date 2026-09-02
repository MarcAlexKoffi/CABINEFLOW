import 'package:cabine_flow/app/app.dart';
import 'package:cabine_flow/core/theme/app_theme.dart';
import 'package:cabine_flow/features/agents/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/commissions/data/repositories/fake_commission_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/fake_network_finance_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/fake_finance_operations_repository.dart';
import 'package:cabine_flow/features/finances/presentation/pages/finances_page.dart';
import 'package:cabine_flow/features/finances/presentation/pages/financial_movements_page.dart';
import 'package:cabine_flow/features/finances/presentation/pages/financial_reconciliation_page.dart';
import 'package:cabine_flow/features/refunds/data/repositories/fake_refund_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/presentation/pages/agent_orders_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/order_history_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/orders_page.dart';
import 'package:cabine_flow/features/payments/presentation/pages/payments_page.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_management_page.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_activity_page.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_issues_page.dart';
import 'package:cabine_flow/features/commissions/presentation/pages/agent_commissions_page.dart';
import 'package:cabine_flow/features/commissions/presentation/pages/agent_performance_page.dart';
import 'package:cabine_flow/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:cabine_flow/features/more/presentation/pages/admin_activity_journal_page.dart';
import 'package:cabine_flow/features/more/presentation/pages/more_page.dart';
import 'package:cabine_flow/features/offers/data/repositories/fake_admin_offer_repository.dart';
import 'package:cabine_flow/features/offers/domain/models/admin_offer.dart';
import 'package:cabine_flow/features/offers/presentation/pages/offer_management_page.dart';
import 'package:cabine_flow/features/support/data/repositories/fake_support_request_repository.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/presentation/pages/support_request_center_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> useCompactPhone(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.izytel/session_preferences'),
      (MethodCall methodCall) async => null,
    );
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

    expect(find.text('Simple. Rapide. Izy.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

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

  testWidgets('historique Admin et filtres restent rendables sur petit écran', (
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
        home: OrderHistoryPage(
          user: admin,
          ordersRepository: ordersRepository,
          onBack: () {},
          onOpenOrder: (order, query, filters) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Historique des commandes'), findsOneWidget);
    expect(find.textContaining('CabineFlow'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Filtres'));
    await tester.pumpAndSettle();

    expect(find.text('Filtres de l’historique'), findsOneWidget);
    expect(find.text('Toutes les périodes'), findsOneWidget);
    expect(find.text('Appliquer'), findsOneWidget);
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
    final Finder financesScrollable = find.byType(Scrollable).first;
    for (final String label in <String>[
      'Gestion financière',
      'Remboursements',
      'Commissions',
      'Rapprochements',
      'Mouvements',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        180,
        scrollable: financesScrollable,
      );
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapprochements financiers restent rendables sur petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    final FakeOrdersRepository ordersRepository = FakeOrdersRepository(
      isTest: true,
    );
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
    final FakeOrdersRepository ordersRepository = FakeOrdersRepository(
      isTest: true,
    );
    final FakeRefundRepository refundRepository = FakeRefundRepository();
    final FakeNetworkFinanceRepository networkFinanceRepository =
        FakeNetworkFinanceRepository();
    final FakeFinanceOperationsRepository financeRepository =
        FakeFinanceOperationsRepository();
    addTearDown(refundRepository.dispose);
    addTearDown(networkFinanceRepository.dispose);
    addTearDown(financeRepository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FinancialMovementsPage(
          ordersRepository: ordersRepository,
          refundRepository: refundRepository,
          commissionRepository: FakeCommissionRepository(),
          networkFinanceRepository: networkFinanceRepository,
          financeRepository: financeRepository,
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

  testWidgets('demandes clients restent rendables sur petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    final FakeSupportRequestRepository supportRepository =
        FakeSupportRequestRepository();
    addTearDown(supportRepository.dispose);
    final FakeRefundRepository refundRepository = FakeRefundRepository();
    addTearDown(refundRepository.dispose);
    final FakeOrdersRepository ordersRepository = FakeOrdersRepository(
      isTest: true,
    );
    final QueueOrder order = (await ordersRepository.fetchPaidQueue()).first;
    await supportRepository.create(
      orderId: order.id,
      orderReference: order.reference,
      type: SupportRequestType.paymentNotRecognized,
      description: 'Paiement effectué mais non reconnu.',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SupportRequestCenterPage(
          user: const AppUser(
            id: 'ADMIN-001',
            name: 'Marc Alex',
            phoneNumber: '0700000000',
            role: UserRole.administrator,
          ),
          repository: supportRepository,
          refundRepository: refundRepository,
          orderHistoryRepository: ordersRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Centre d’assistance'), findsOneWidget);
    expect(find.text('À traiter'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gestion agents reste rendable sur petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AgentManagementPage(
          user: const AppUser(
            id: 'ADMIN-001',
            name: 'Marc Alex',
            phoneNumber: '0700000000',
            role: UserRole.administrator,
          ),
          repository: FakeAgentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agents & zones'), findsOneWidget);
    expect(find.text('Ajouter un agent'), findsOneWidget);
    expect(find.text('Koffi Kouassi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalogue offres reste rendable sur petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    final FakeAdminOfferRepository repository = FakeAdminOfferRepository(
      initialOffers: <AdminOffer>[
        const AdminOffer(
          id: 'orange-1',
          network: MobileNetwork.orange,
          service: OfferService.internet,
          operationType: OrderOperationType.internetSubscription,
          title: 'Internet Orange 4 Go',
          catalogLabel: 'Internet Orange 4 Go',
          sellingPrice: 1000,
          details: <String>['4 Go'],
          category: 'internet',
          isActive: true,
          displayOrder: 1,
          volume: '4 Go',
          validity: '7 jours',
        ),
      ],
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OfferManagementPage(
          user: const AppUser(
            id: 'ADMIN-001',
            name: 'Marc Alex',
            phoneNumber: '0700000000',
            role: UserRole.administrator,
          ),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Offres'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Internet Orange 4 Go'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Internet Orange 4 Go'), findsOneWidget);
    expect(find.text('1 000 F'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page Plus administration reste rendable sur petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    final FakeAdminOfferRepository offerRepository = FakeAdminOfferRepository();
    addTearDown(offerRepository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MorePage(
          user: const AppUser(
            id: 'ADMIN-001',
            name: 'Marc Alex',
            phoneNumber: '0700000000',
            role: UserRole.administrator,
          ),
          authRepository: FakeAuthRepository(),
          adminOfferRepository: offerRepository,
          agentRepository: FakeAgentRepository(),
          ordersRepository: FakeOrdersRepository(isTest: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('Demandes clients'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Journal d’activité'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Journal d’activité'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('journal administration reste rendable sur petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    final FakeSupportRequestRepository supportRepository =
        FakeSupportRequestRepository();
    addTearDown(supportRepository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminActivityJournalPage(
          user: const AppUser(
            id: 'ADMIN-001',
            name: 'Marc',
            phoneNumber: '',
            role: UserRole.administrator,
          ),
          orderHistoryRepository: FakeOrdersRepository(isTest: true),
          supportRequestRepository: supportRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Journal d’activité'), findsOneWidget);
    expect(find.text('Activité récente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profil Agent reste rendable sur petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AgentActivityPage(
          onOpenActivity: () {},
          onOpenCommissions: () {},
          user: const AppUser(
            id: 'AGENT-001',
            name: 'Koffi Kouassi',
            phoneNumber: '0700000001',
            role: UserRole.agent,
          ),
          repository: FakeAgentRepository(),
          isLoggingOut: false,
          onLogout: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profil'), findsOneWidget);

    // Sur 320x568, les informations du profil peuvent etre sous le pli :
    // on verifie leur accessibilite par scroll plutot que leur presence dans
    // le viewport initial. Les performances et commissions vivent sur Accueil.
    for (final String label in <String>[
      'Informations personnelles',
      'Mes signalements',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('performances Agent restent rendables sur petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AgentPerformancePage(
          user: const AppUser(
            id: 'AGENT-001',
            name: 'Koffi Kouassi',
            phoneNumber: '0700000001',
            role: UserRole.agent,
          ),
          repository: FakeCommissionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mes performances'), findsWidgets);
    expect(find.text('Ce mois'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('commissions Agent restent rendables sur petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AgentCommissionsPage(
          user: const AppUser(
            id: 'AGENT-001',
            name: 'Koffi Kouassi',
            phoneNumber: '0700000001',
            role: UserRole.agent,
          ),
          repository: FakeCommissionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mes commissions'), findsOneWidget);
    expect(find.text('SOLDE DE COMMISSIONS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signalements Agent restent rendables sur petit écran', (
    WidgetTester tester,
  ) async {
    await useCompactPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AgentIssuesPage(
          agentId: 'AGENT-001',
          repository: FakeAgentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mes signalements'), findsOneWidget);
    expect(find.text('Signaler un problème'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
