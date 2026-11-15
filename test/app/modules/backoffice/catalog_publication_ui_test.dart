import 'dart:math';
import 'package:cabine_flow/app/data/repositories/fake_admin_offer_repository.dart';
import 'package:cabine_flow/app/domain/entities/auth/app_user.dart';
import 'package:cabine_flow/app/domain/entities/offers/admin_offer.dart';
import 'package:cabine_flow/app/domain/entities/offers/catalog_import.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/modules/backoffice/views/catalog/backoffice_offers_page.dart';
import 'package:cabine_flow/app/modules/backoffice/views/catalog/catalog_import_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/catalog_import_fixture.dart';
import '../../../support/catalog_visual_fonts.dart';

AdminOffer offer(int index, {bool active = false}) => AdminOffer(
  id: 'offer-$index',
  network: MobileNetwork.orange,
  service: OfferService.internet,
  operationType: OrderOperationType.internetSubscription,
  title: 'Forfait $index',
  catalogLabel: 'Forfait $index',
  sellingPrice: 1000,
  details: const [],
  category: 'internet',
  isActive: active,
  displayOrder: index,
  offerCode: 'OR-$index',
  catalogStatus: active ? 'ACTIF' : 'BROUILLON',
  catalogVersion: index + 1,
);

class PublicationFixture extends CatalogImportFixture {
  List<Map<String, dynamic>> items = [];
  bool allBlocked = false, conflict = false;
  String id = '00000000-0000-4000-8000-000000000002';
  bool blocked(int index) => allBlocked || index % 5 == 0;
  int get errors => List.generate(items.length, (i) => i).where(blocked).length;
  List<Map<String, dynamic>> get lines => [
    for (var i = 0; i < items.length; i++)
      {
        'line_number': i + 2,
        'code': items[i]['id'],
        'kind': blocked(i) ? 'error' : 'update',
        'data': {
          'nom_affiche': 'Forfait $i',
          'prix_fcfa': '1000',
          'statut': 'ACTIF',
        },
        'changes': {
          'statut': {'before': 'BROUILLON', 'after': 'ACTIF'},
        },
        'errors': blocked(i) ? ['prix_fcfa : nombre invalide.'] : [],
      },
  ];
  @override
  Map<String, dynamic> get document => {
    'job': {
      'id': id,
      'file_name': 'Modification groupée : activate',
      'status': status,
      'total': items.length,
      'cursor': cursor,
    },
    'summary': {
      'update': items.length - errors,
      'error': errors,
      'unchanged': 0,
      'applied': status == 'completed'
          ? items.length - errors - (conflict ? 1 : 0)
          : 0,
      'conflict': status == 'completed' && conflict ? 1 : 0,
    },
    'filteredTotal': items.length,
    'lines': lines.take(20).toList(),
  };
  @override
  Future<String> prepareBulk({
    required String requestId,
    required String operation,
    String? value,
    required List<Map<String, dynamic>> items,
  }) async {
    expect(operation, 'activate');
    calls.add('prepare:$requestId');
    id = requestId;
    this.items = items;
    return id;
  }

  @override
  Future<CatalogImportPage> importPage(
    String id, {
    int offset = 0,
    String filter = 'all',
  }) async {
    calls.add('read:$id:$offset:$filter');
    final filtered = lines
        .where((line) => filter == 'all' || line['kind'] == filter)
        .toList();
    return CatalogImportPage({
      ...document,
      'filteredTotal': filtered.length,
      'lines': filtered.skip(offset).take(20).toList(),
    });
  }

  @override
  Future<CatalogImportPage> confirmImport(
    String id, {
    required bool allowPartial,
  }) async {
    expect(allowPartial, errors > 0);
    calls.add('confirm:$id');
    status = 'running';
    return CatalogImportPage(document);
  }

  @override
  Future<CatalogImportPage> applyImportBatch(String id) async {
    calls.add('apply:$id');
    cursor = min(items.length, cursor + 50);
    if (cursor == items.length) status = 'completed';
    if (loseReply) {
      loseReply = false;
      throw StateError('response lost');
    }
    return CatalogImportPage(document);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ThemeData theme;
  setUpAll(() async => theme = await catalogVisualTheme());
  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester,
    PublicationFixture repo, {
    int count = 100,
    String? resumeId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CatalogImportDialog(
                  repository: repo,
                  importId: resumeId,
                  publicationOffers: resumeId == null
                      ? List.generate(count, offer)
                      : null,
                ),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tap(tester, 'Ouvrir');
  }

  testWidgets(
    '100 offers across five catalogue pages, active offers excluded, preview never publishes',
    (tester) async {
      viewport(tester, 390);
      final repo = FakeAdminOfferRepository(
        initialOffers: [
          for (var i = 0; i < 100; i++) offer(i),
          offer(100, active: true),
        ],
      );
      addTearDown(repo.dispose);
      final imports = PublicationFixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SingleChildScrollView(
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
      await tap(tester, 'Publier les offres');
      expect(find.text('100 offres non publiées à contrôler'), findsOneWidget);
      expect(imports.calls, isEmpty);
      await tap(tester, 'Vérifier les offres');
      expect(imports.items.length, 100);
      expect(imports.items.singleWhere((item) => item['id'] == 'offer-99'), {
        'id': 'offer-99',
        'version': 100,
      });
      expect(imports.items.any((item) => item['id'] == 'offer-100'), false);
      expect(find.text('80 Activables'), findsOneWidget);
      expect(find.text('20 Bloquées'), findsOneWidget);
      expect(
        imports.calls.any(
          (call) => call.startsWith('confirm:') || call.startsWith('apply:'),
        ),
        false,
      );
      expect(tester.takeException(), isNull);
      await tap(tester, 'Fermer');
      expect(
        (await repo.fetchOffers()).where((offer) => offer.isActive).length,
        1,
      );
      final search = find.byType(TextField).first;
      await tester.ensureVisible(search);
      await tester.enterText(search, 'OR-9');
      await tester.pumpAndSettle();
      await tap(tester, 'Publier les offres');
      expect(find.text('11 offres non publiées à contrôler'), findsOneWidget);
      await tap(tester, 'Vérifier les offres');
      expect(imports.items.length, 11);
      expect(
        imports.items.every(
          (item) => (item['id'] as String).startsWith('offer-9'),
        ),
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mixed publication needs explicit exclusion and confirmation; interrupted batches resume without a second confirmation',
    (tester) async {
      viewport(tester, 1440);
      final repo = PublicationFixture()
        ..loseReply = true
        ..conflict = true;
      await open(tester, repo);
      await tap(tester, 'Vérifier les offres');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Continuer'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('prix_fcfa : nombre invalide.'), findsNWidgets(4));
      await tester.ensureVisible(find.byTooltip('Page suivante'));
      await tester.tap(find.byTooltip('Page suivante'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('read:${repo.id}:20:all'));
      await tap(tester, 'Publier uniquement les offres activables');
      await tap(tester, 'Continuer');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Publier 80 offres'),
            )
            .onPressed,
        isNull,
      );
      await tap(
        tester,
        'Je confirme la publication des offres activables uniquement.',
      );
      await tap(tester, 'Publier 80 offres');
      expect(find.textContaining('Opération interrompue.'), findsOneWidget);
      await tap(tester, 'Reprendre le traitement');
      expect(find.text('Publication terminée'), findsOneWidget);
      expect(
        find.text(
          '79 offres publiées · 20 bloquées · 1 conflits · 100 / 100 examinées',
        ),
        findsOneWidget,
      );
      expect(repo.calls.where((call) => call.startsWith('confirm:')).length, 1);
      expect(repo.calls.where((call) => call.startsWith('apply:')).length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all blocked cannot publish, even after accepting their exclusion',
    (tester) async {
      viewport(tester, 320);
      final repo = PublicationFixture()..allBlocked = true;
      await open(tester, repo, count: 3);
      await tap(tester, 'Vérifier les offres');
      expect(find.text('0 Activables'), findsOneWidget);
      expect(find.textContaining('Aucune offre activable.'), findsOneWidget);
      await tap(tester, 'Publier uniquement les offres activables');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Continuer'),
            )
            .onPressed,
        isNull,
      );
      expect(repo.calls.any((call) => call.startsWith('confirm:')), false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history recognizes a publication and resumes its persisted job',
    (tester) async {
      viewport(tester, 768);
      final repo = PublicationFixture()
        ..items = [
          for (var i = 0; i < 100; i++) {'id': 'offer-$i', 'version': i + 1},
        ]
        ..cursor = 50
        ..status = 'running';
      await open(tester, repo, resumeId: repo.id);
      expect(find.text('Publier les offres'), findsOneWidget);
      expect(find.text('Choisir un fichier'), findsNothing);
      await tap(tester, 'Reprendre le traitement');
      expect(find.text('Publication terminée'), findsOneWidget);
      expect(
        repo.calls.where(
          (call) => call.startsWith('prepare:') || call.startsWith('confirm:'),
        ),
        isEmpty,
      );
      expect(repo.cursor, 100);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'oversized publication asks to narrow filters without a server request',
    (tester) async {
      viewport(tester, 1440);
      final repo = PublicationFixture();
      await open(tester, repo, count: 501);
      await tap(tester, 'Vérifier les offres');
      expect(
        find.textContaining('Sélectionnez entre 1 et 500 offres.'),
        findsOneWidget,
      );
      expect(repo.calls, isEmpty);
    },
  );
}
