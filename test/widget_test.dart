import 'package:cabine_flow/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> configureMobileScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openLoginPage(WidgetTester tester) async {
    await configureMobileScreen(tester);

    await tester.pumpWidget(const CabineFlowApp());

    // Le splash dure 2,5 secondes.
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();

    expect(find.text('Connexion à votre espace'), findsOneWidget);
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

  testWidgets('affiche le splash screen puis la connexion', (
    WidgetTester tester,
  ) async {
    await configureMobileScreen(tester);

    await tester.pumpWidget(const CabineFlowApp());

    // Éléments réellement présents sur le nouveau splash.
    expect(find.text('Chargement...'), findsOneWidget);
    expect(find.text('Commandes & transactions simplifiées'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();

    expect(find.text('Connexion à votre espace'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
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

    // Le nouveau design utilise un indicateur, pas le texte "Connexion...".
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // FakeAuthRepository attend environ 1 seconde.
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    expect(find.text('Bonjour Marc'), findsOneWidget);

    // FakeDashboardRepository attend environ 800 ms.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.text('Activité du jour'), findsOneWidget);
    expect(find.text('Statut des commandes payées'), findsOneWidget);
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

    await tester.tap(find.text('Commandes'));
    await tester.pumpAndSettle();

    expect(find.text('File d’attente'), findsOneWidget);

    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();

    expect(find.text('Activité du jour'), findsOneWidget);
  });
}
