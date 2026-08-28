import 'package:cabine_flow/core/theme/app_theme.dart';
import 'package:cabine_flow/features/support/presentation/widgets/support_resolution_note_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showModalBottomSheet<String>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const SupportResolutionNoteDialog(),
                    );
                  },
                  child: const Text('Ouvrir'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('Annuler ferme le formulaire sans erreur de controller', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    expect(find.text('Résoudre la demande'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Résoudre la demande'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('une note trop courte reste dans le formulaire', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.text('Valider'));
    await tester.pump();

    expect(find.text('Ajoutez une note de résolution.'), findsOneWidget);
    expect(find.text('Résoudre la demande'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('une note valide ferme le formulaire sans erreur', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    await tester.enterText(
      find.byType(TextField),
      'Paiement retrouvé et commande régularisée.',
    );
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(find.text('Résoudre la demande'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le formulaire reste compact sur une largeur mobile', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await openSheet(tester);

    final Size sheetSize = tester.getSize(
      find.byType(SupportResolutionNoteDialog),
    );
    expect(sheetSize.width, lessThanOrEqualTo(360));
    expect(sheetSize.height, lessThan(560));
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Valider'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
