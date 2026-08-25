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

  testWidgets('affiche les trois onglets et accepte une commande', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);
    final QueueOrder order = (await repository.fetchPaidQueue()).first;
    await repository.assignToAgent(
      orderId: order.id,
      agentId: agent.id,
      assignedByUserId: 'ADMIN-001',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: AgentOrdersPage(user: agent, ordersRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    // Régression 9B : la carte doit pouvoir être peinte sans exception.
    // Un Border non uniforme combiné à un borderRadius pouvait transformer
    // la carte en grand bloc vide/sombre sur l'appareil.
    expect(tester.takeException(), isNull);
    expect(find.text(order.reference), findsOneWidget);

    expect(find.text('Mes commandes'), findsOneWidget);
    expect(find.text('À accepter'), findsOneWidget);
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('Terminées'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);

    await tester.tap(find.text('Accepter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Aucune commande en cours'), findsNothing);
    expect(find.text(order.reference), findsOneWidget);
  });

  testWidgets('demande un motif avant de refuser une commande', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);
    final QueueOrder order = (await repository.fetchPaidQueue()).first;
    await repository.assignToAgent(
      orderId: order.id,
      agentId: agent.id,
      assignedByUserId: 'ADMIN-001',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: AgentOrdersPage(user: agent, ordersRepository: repository),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Refuser'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Refuser la commande'), findsOneWidget);
    expect(find.text('Motif du refus'), findsOneWidget);

    await tester.tap(find.text('Confirmer le refus'));
    await tester.pump();
    expect(find.text('Précise la raison du refus.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'Réseau momentanément indisponible',
    );
    await tester.tap(find.text('Confirmer le refus'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Aucune commande à accepter'), findsOneWidget);
    final List<QueueOrder> remaining = await repository
        .watchAssignedOrders(agentId: agent.id)
        .first;
    expect(remaining, isEmpty);
  });
}
