import 'package:cabine_flow/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openLoginPage(WidgetTester tester) async {
    await tester.pumpWidget(const CabineFlowApp());

    await tester.pump(const Duration(milliseconds: 2600));

    await tester.pumpAndSettle();
  }

  testWidgets('affiche le splash screen puis la connexion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CabineFlowApp());

    expect(find.text('CabineFlow'), findsOneWidget);

    expect(find.text('Vos commandes, simplement organisées'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2600));

    await tester.pumpAndSettle();

    expect(find.text('Connexion à votre espace'), findsOneWidget);

    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('refuse un formulaire vide', (WidgetTester tester) async {
    await openLoginPage(tester);

    await tester.tap(find.text('Se connecter'));

    await tester.pump();

    expect(find.text('Saisis ton adresse e-mail.'), findsOneWidget);

    expect(find.text('Saisis ton mot de passe.'), findsOneWidget);
  });

  testWidgets('ouvre le tableau de bord après une connexion réussie', (
    WidgetTester tester,
  ) async {
    await openLoginPage(tester);

    final Finder fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), 'marc@cabineflow.app');

    await tester.enterText(fields.at(1), '1234');

    await tester.tap(find.text('Se connecter'));

    await tester.pump();

    expect(find.text('Connexion...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));

    await tester.pumpAndSettle();

    expect(find.text('Bonjour Marc'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));

    await tester.pumpAndSettle();

    expect(find.text('28 commandes à traiter'), findsOneWidget);
  });

  testWidgets('permet de changer d’onglet après la connexion', (
    WidgetTester tester,
  ) async {
    await openLoginPage(tester);

    final Finder fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), 'marc@cabineflow.app');

    await tester.enterText(fields.at(1), '1234');

    await tester.tap(find.text('Se connecter'));

    await tester.pump(const Duration(milliseconds: 1100));

    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 900));

    await tester.pumpAndSettle();

    expect(find.text('28 commandes à traiter'), findsOneWidget);

    await tester.tap(find.text('Commandes'));

    await tester.pumpAndSettle();

    expect(find.text('File d’attente'), findsOneWidget);

    await tester.tap(find.text('Accueil'));

    await tester.pumpAndSettle();

    expect(find.text('28 commandes à traiter'), findsOneWidget);
  });
}
