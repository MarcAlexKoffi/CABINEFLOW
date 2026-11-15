import 'dart:io';
import 'dart:ui' as ui;
import 'package:cabine_flow/app/data/repositories/fake_admin_offer_repository.dart';
import 'package:cabine_flow/app/domain/entities/auth/app_user.dart';
import 'package:cabine_flow/app/domain/entities/offers/admin_offer.dart';
import 'package:cabine_flow/app/domain/entities/offers/catalog_import.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/modules/backoffice/views/catalog/backoffice_offers_page.dart';
import 'package:cabine_flow/app/modules/backoffice/views/catalog/catalog_import_dialog.dart';
import 'package:cabine_flow/app/modules/backoffice/widgets/backoffice_order_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/catalog_import_fixture.dart';
import '../../../support/catalog_visual_fonts.dart';

class _ValidFileImport extends CatalogImportFixture {
  @override
  Map<String, dynamic> get document {
    final value = super.document;
    return {
      ...value,
      'job': {...value['job'] as Map, 'total': 1},
      'summary': {...value['summary'] as Map, 'error': 0},
      'filteredTotal': 1,
      'lines': (value['lines'] as List).take(1).toList(),
    };
  }

  @override
  Future<CatalogImportPage> confirmImport(
    String id, {
    required bool allowPartial,
  }) async {
    expect(allowPartial, false);
    calls.add('confirm:$id');
    status = 'running';
    return CatalogImportPage(document);
  }

  @override
  Future<CatalogImportPage> applyImportBatch(String id) async {
    calls.add('apply:$id');
    status = 'completed';
    cursor = 1;
    return CatalogImportPage(document);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ThemeData theme;
  setUpAll(() async {
    theme = await catalogVisualTheme();
  });
  Future<void> open(
    WidgetTester tester,
    CatalogImportFixture repo, {
    String? id,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    CatalogImportDialog(repository: repo, importId: id),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'preview has no writes; one import-and-publish confirmation with explicit duplicate exclusion; lost reply resumes same ID',
    (tester) async {
      viewport(tester, 1440);
      final repo = CatalogImportFixture()..loseReply = true;
      final id = repo.document['job']['id'] as String;
      await open(tester, repo, id: id);
      expect(repo.calls.every((call) => call.startsWith('read:')), true);
      expect(
        find.textContaining('Code répété aux lignes 3, 4.'),
        findsNWidgets(2),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Importer et publier'),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, 'Traiter uniquement les lignes valides');
      expect(
        find.text(
          'Je confirme ces changements et le périmètre des lignes exclues.',
        ),
        findsNothing,
      );
      await tap(tester, 'Importer et publier');
      expect(repo.calls.where((call) => call.startsWith('confirm:')).length, 1);
      expect(find.textContaining('Opération interrompue.'), findsOneWidget);
      await tap(tester, 'Reprendre le traitement');
      expect(find.text('Traitement terminé'), findsOneWidget);
      expect(repo.calls.where((call) => call == 'apply:$id').length, 2);
      expect(repo.cursor, 3);
      await tap(tester, 'Restaurer la version précédente');
      expect(repo.calls.where((call) => call.startsWith('restore:')), isEmpty);
      await tap(tester, 'Restaurer');
      expect(find.text('Révision restaurée'), findsOneWidget);
      expect(repo.calls.last, 'restore:$id');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'valid file publishes with one button, without verification or extra confirmation screens',
    (tester) async {
      viewport(tester, 390);
      final repo = _ValidFileImport();
      await open(tester, repo, id: repo.document['job']['id'] as String);
      expect(find.textContaining('ACTIF'), findsWidgets);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text('Continuer'), findsNothing);
      expect(repo.calls.where((call) => call.startsWith('confirm:')), isEmpty);
      await tap(tester, 'Importer et publier');
      expect(find.text('Traitement terminé'), findsOneWidget);
      expect(repo.calls.where((call) => call.startsWith('confirm:')).length, 1);
      expect(repo.calls.where((call) => call.startsWith('apply:')).length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets(
      'real import dialog fits $width px and retains existing BO surface',
      (tester) async {
        viewport(tester, width);
        final repo = CatalogImportFixture();
        await open(tester, repo);
        expect(find.text('Choisir un fichier'), findsOneWidget);
        expect(find.text('Télécharger le modèle'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (width == 390 || width == 1440) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('catalog-dialog-surface')),
            );
            final image = await boundary.toImage(pixelRatio: 1);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final dir = Directory('docs/catalog_offers/implementation-captures')
              ..createSync(recursive: true);
            File(
              '${dir.path}/import_flutter_${width.toInt()}.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        if (width == 1440) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        } else {
          await tap(tester, 'Fermer');
        }
        expect(find.byType(CatalogImportDialog), findsNothing);
        expect(repo.calls, isEmpty);
      },
    );
  }
  testWidgets(
    'non-admin page exposes no import, price editor or publication settings',
    (tester) async {
      viewport(tester, 1440);
      final repo = FakeAdminOfferRepository();
      addTearDown(repo.dispose);
      final imports = CatalogImportFixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: BackofficeOffersPage(
                user: const AppUser(
                  id: 'manager',
                  name: 'Manager',
                  phoneNumber: '',
                  role: UserRole.manager,
                ),
                repository: repo,
                importRepository: imports,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Importer un fichier'), findsNothing);
      expect(find.text('Publier les offres'), findsNothing);
      expect(find.text('Nouvelle offre'), findsNothing);
      expect(find.text('Règles et familles'), findsNothing);
      expect(imports.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'admin import actions wrap without overflowing at desktop content widths',
    (tester) async {
      viewport(tester, 930);
      final repo = FakeAdminOfferRepository();
      addTearDown(repo.dispose);
      final imports = CatalogImportFixture();
      for (final width in [840.0, 884.0, 930.0, 1024.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: BackofficeOffersPage(
                  user: const AppUser(
                    id: 'admin',
                    name: 'Admin',
                    phoneNumber: '',
                    role: UserRole.administrator,
                  ),
                  repository: repo,
                  importRepository: imports,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$width px');
        final intro = tester.getRect(find.byType(BackofficePageIntro));
        expect(intro.height, lessThan(500), reason: '$width px');
        for (final label in [
          'Importer un fichier',
          'Publier les offres',
          'Exporter le catalogue',
          'Historique des imports',
          'Règles et familles',
          'Synchroniser historique',
          'Nouvelle offre',
        ]) {
          final button = tester.getRect(find.text(label));
          expect(intro.contains(button.topLeft), isTrue, reason: label);
          expect(intro.contains(button.bottomRight), isTrue, reason: label);
        }
      }
    },
  );
  testWidgets(
    'admin catalogue retains responsive cards, table selection and structured editor',
    (tester) async {
      viewport(tester, 1440);
      final data = <String, dynamic>{
        'action': 'UPSERT',
        'code_offre': 'OR-EXAMPLE',
        'operateur': 'ORANGE',
        'famille': 'INTERNET',
        'type_forfait': 'INTERNET',
        'nom_affiche': '1,5 GO',
        'prix_fcfa': '1000',
        'volume_data': '1.5',
        'unite_data': 'GO',
        'duree_valeur': '7',
        'duree_unite': 'JOUR',
        'statut': 'BROUILLON',
        'mis_en_avant': 'NON',
        'ordre_affichage': '1',
        'activable_pour_tiers': 'A_VERIFIER',
        'canal_activation': 'A_VERIFIER',
      };
      final repo = FakeAdminOfferRepository(
        initialOffers: [
          for (var index = 0; index < 2; index++)
            AdminOffer(
              id: 'offer-$index',
              network: MobileNetwork.orange,
              service: OfferService.internet,
              operationType: OrderOperationType.internetSubscription,
              title: '1,5 GO',
              catalogLabel: 'Internet Orange 1,5 Go - 7 jours',
              sellingPrice: 1000,
              details: [],
              category: 'internet',
              isActive: false,
              displayOrder: index,
              catalogStatus: 'BROUILLON',
              catalogVersion: 1,
              offerCode: 'OR-EXAMPLE-$index',
              familyCode: 'INTERNET',
              codeConfirmed: true,
              importData: {...data, 'code_offre': 'OR-EXAMPLE-$index'},
              volume: '1.5 GO',
              validity: '7 jours',
            ),
        ],
      );
      addTearDown(repo.dispose);
      final imports = CatalogImportFixture();
      for (final width in [320.0, 390.0, 768.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 1800);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: BackofficeOffersPage(
                  user: const AppUser(
                    id: 'admin',
                    name: 'Admin',
                    phoneNumber: '',
                    role: UserRole.administrator,
                  ),
                  repository: repo,
                  importRepository: imports,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Importer un fichier'), findsOneWidget);
        expect(find.text('Règles et familles'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      final a = tester.getTopLeft(
            find.byKey(const ValueKey('catalog-card-offer-0')),
          ),
          b = tester.getTopLeft(
            find.byKey(const ValueKey('catalog-card-offer-1')),
          );
      expect(b.dx, greaterThan(a.dx));
      expect(a.dy, b.dy);
      await tester.ensureVisible(find.text('Cartes'));
      await tester.tap(find.text('Cartes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tableau sur grand écran').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Checkbox).first);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tap(tester, 'Publier la sélection');
      expect(
        find.text('Sélection du catalogue, toutes les pages'),
        findsOneWidget,
      );
      expect(find.text('1 offres non publiées à contrôler'), findsOneWidget);
      await tap(tester, 'Fermer');
      await tester.ensureVisible(find.byType(Checkbox).first);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tap(tester, 'Modifier la sélection');
      expect(find.text('Voir les impacts'), findsOneWidget);
      await tap(tester, 'Annuler');
      await tap(tester, 'Nouvelle offre');
      expect(find.text('Code permanent'), findsOneWidget);
      expect(
        find.textContaining('Le statut ACTIF rend l’offre disponible.'),
        findsOneWidget,
      );
      for (final entry in {
        'Code permanent': 'OR-CREATE',
        'Nom affiché': 'Nouveau brouillon',
        'Prix opérateur (FCFA)': '500',
        'Durée': '7',
      }.entries) {
        final field = find.widgetWithText(TextFormField, entry.key);
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      await tap(tester, 'Enregistrer');
      expect(imports.calls, contains('save:OR-CREATE'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
