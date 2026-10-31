import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/ussd/presentation/backoffice_ussd_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ussd_test_doubles.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    UssdTestRepository repo,
    UserRole role,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: BackofficeUssdPage(
              user: AppUser(
                id: 'synthetic',
                name: 'Test',
                phoneNumber: '',
                role: role,
              ),
              repository: repo,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Manager sees rules and anomalies with no edit controls', (
    tester,
  ) async {
    await mount(tester, UssdTestRepository(), UserRole.manager);
    expect(find.text('Créer une règle'), findsNothing);
    expect(find.text('Associer les offres'), findsNothing);
    expect(find.text('Anomalies USSD'), findsOneWidget);
  });
  testWidgets(
    'new rule stays a draft; preview static code needs no beneficiary',
    (tester) async {
      final repo = UssdTestRepository();
      await mount(tester, repo, UserRole.administrator);
      await tester.tap(find.text('Créer une règle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Template USSD'),
        '*999*2#',
      );
      await tester.tap(find.text('Tester'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Générer sans lancer'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.text('*999*2#'),
        ),
        findsNWidgets(2),
      );
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer en brouillon'));
      await tester.pumpAndSettle();
      expect(repo.saved?['ussd_template'], '*999*2#');
      expect(repo.statusChanges, 0);
    },
  );
  testWidgets('activation requires explicit SIM confirmation', (tester) async {
    final repo = UssdTestRepository();
    await mount(tester, repo, UserRole.administrator);
    await tester.ensureVisible(find.byTooltip('Activer après validation SIM'));
    await tester.tap(find.byTooltip('Activer après validation SIM'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Activer cette version'),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Type de SIM testé (aucun numéro)'),
      'SIM cabine de test',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activer cette version'));
    await tester.pumpAndSettle();
    expect(repo.statusChanges, 1);
  });
}
