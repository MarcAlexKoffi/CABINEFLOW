import 'package:cabine_flow/core/theme/app_theme.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/presentation/pages/agent_orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const AppUser agent = AppUser(
    id: 'AGENT-001',
    name: 'Koffi Kouassi',
    phoneNumber: '0700000001',
    role: UserRole.agent,
  );

  Future<QueueOrder> prepareAssignedOrder(FakeOrdersRepository repository) async {
    final QueueOrder order = (await repository.fetchPaidQueue()).first;
    await repository.assignToAgent(
      orderId: order.id,
      agentId: agent.id,
      assignedByUserId: 'ADMIN-001',
    );
    return order;
  }

  Future<void> pumpAgentPage(
    WidgetTester tester,
    FakeOrdersRepository repository,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AgentOrdersPage(user: agent, ordersRepository: repository),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('affiche la file priorisée de la maquette et accepte', (
    WidgetTester tester,
  ) async {
    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);
    final QueueOrder order = await prepareAssignedOrder(repository);
    await pumpAgentPage(tester, repository);

    expect(tester.takeException(), isNull);
    expect(find.text('Bonjour Koffi 👋'), findsOneWidget);
    expect(find.text('1 commande à traiter'), findsOneWidget);
    expect(find.text('PRIORITÉ 1'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
    expect(find.text('Mes commandes'), findsNothing);

    await tester.tap(find.text('Accepter'));
    await tester.pumpAndSettle();

    expect(find.text('Détail commande'), findsOneWidget);
    expect(find.text(order.reference), findsOneWidget);
    expect(find.text('Client'), findsOneWidget);
    expect(find.text('Paiement'), findsOneWidget);
    expect(find.text('Détails de l’offre'), findsOneWidget);
    expect(find.text('Preuve'), findsOneWidget);
    expect(find.text('Marquer comme réussie'), findsOneWidget);
  });

  testWidgets('demande toujours un motif avant de refuser', (
    WidgetTester tester,
  ) async {
    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);
    final QueueOrder order = await prepareAssignedOrder(repository);
    await pumpAgentPage(tester, repository);

    await tester.tap(find.text(order.offerLabel));
    await tester.pumpAndSettle();

    expect(find.text('Détail commande'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('agent-order-detail-actions')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refuser la commande'));
    await tester.pumpAndSettle();

    expect(find.text('Refuser la commande'), findsOneWidget);
    expect(find.text('Motif du refus'), findsOneWidget);

    await tester.tap(find.text('Confirmer le refus'));
    await tester.pumpAndSettle();

    // Le refus sans motif doit être bloqué et le bottom sheet doit rester ouvert.
    expect(find.text('Refuser la commande'), findsOneWidget);
    final TextField refusalField = tester.widget<TextField>(
      find.byType(TextField),
    );
    // On teste la présence de la validation, pas une formulation exacte :
    // le libellé UX peut évoluer sans casser le comportement métier.
    expect(refusalField.decoration?.errorText, isNotNull);
    expect(refusalField.decoration!.errorText!, isNotEmpty);

    final List<QueueOrder> stillAssigned = await repository
        .watchAssignedOrders(agentId: agent.id)
        .first;
    expect(stillAssigned, hasLength(1));

    await tester.enterText(
      find.byType(TextField),
      'Réseau momentanément indisponible',
    );
    await tester.tap(find.text('Confirmer le refus'));
    await tester.pumpAndSettle();

    final List<QueueOrder> remaining = await repository
        .watchAssignedOrders(agentId: agent.id)
        .first;
    expect(remaining, isEmpty);
  });
}
