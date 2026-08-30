import 'package:cabine_flow/app/app.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> configureMobileScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openLoginPage(
    WidgetTester tester, {
    OrdersRepository? ordersRepository,
  }) async {
    await configureMobileScreen(tester);
    await tester.pumpWidget(CabineFlowApp(ordersRepository: ordersRepository));
    await tester.pump();

    expect(find.text('Bienvenue'), findsOneWidget);
    expect(find.text('Simple. Rapide. Fiable.'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  }

  Future<void> tapLoginButton(WidgetTester tester) async {
    final Finder loginButton = find.widgetWithText(
      FilledButton,
      'Se connecter',
    );

    expect(loginButton, findsOneWidget);
    await tester.ensureVisible(loginButton);
    await tester.pumpAndSettle();
    await tester.tap(loginButton);
    await tester.pump();
  }

  testWidgets('ouvre directement la maquette Splash & Connexion', (
    WidgetTester tester,
  ) async {
    await openLoginPage(tester);

    expect(find.text('Bienvenue'), findsOneWidget);
    expect(
      find.text('Connectez-vous à votre espace\npour continuer'),
      findsOneWidget,
    );
    expect(find.text('Continuer avec Google'), findsOneWidget);
    expect(find.text('Votre espace professionnel'), findsNothing);
  });

  testWidgets('refuse un formulaire vide', (WidgetTester tester) async {
    await openLoginPage(tester);
    await tapLoginButton(tester);

    expect(find.text('Saisis ton adresse e-mail.'), findsOneWidget);
    expect(find.text('Saisis ton mot de passe.'), findsOneWidget);
  });

  testWidgets('ouvre le tableau de bord après une connexion réussie', (
    WidgetTester tester,
  ) async {
    await openLoginPage(tester);

    final Finder fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));

    await tester.enterText(fields.at(0), 'marc@cabineflow.app');
    await tester.enterText(fields.at(1), '1234');
    await tapLoginButton(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bonjour Marc'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.text('Activité du jour'), findsOneWidget);
    expect(find.text('À faire maintenant'), findsOneWidget);
  });

  testWidgets('permet de changer d’onglet après la connexion', (
    WidgetTester tester,
  ) async {
    await openLoginPage(tester);

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'marc@cabineflow.app');
    await tester.enterText(fields.at(1), '1234');
    await tapLoginButton(tester);

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.text('Activité du jour'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('admin-nav-commandes')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('À traiter'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('admin-nav-accueil')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Activité du jour'), findsOneWidget);
  });

  testWidgets('ouvre la file Agent de la maquette et conserve le profil', (
    WidgetTester tester,
  ) async {
    final FakeOrdersRepository ordersRepository = FakeOrdersRepository(
      isTest: true,
    );
    final QueueOrder order = (await ordersRepository.fetchPaidQueue()).first;
    await ordersRepository.assignToAgent(
      orderId: order.id,
      agentId: 'AGENT-001',
      assignedByUserId: 'ADMIN-001',
    );

    await openLoginPage(tester, ordersRepository: ordersRepository);

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'agent@cabineflow.app');
    await tester.enterText(fields.at(1), '1234');
    await tapLoginButton(tester);

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bonjour'), findsOneWidget);
    expect(find.textContaining('commande'), findsWidgets);
    expect(find.text('Accepter'), findsWidgets);
    expect(find.text('Mes commandes'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('agent-nav-profil')));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.text('Mon Activité'), findsOneWidget);
    expect(find.text('Statut Agent'), findsOneWidget);
  });
}
