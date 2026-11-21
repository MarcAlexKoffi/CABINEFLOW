import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cabine_flow/app/domain/entities/offers/admin_offer.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/domain/repositories/catalog_bonus_repository.dart';
import 'package:cabine_flow/app/modules/backoffice/views/catalog/catalog_bonus_dialogs.dart';

class BonusFake implements CatalogBonusRepository {
  Map<String, dynamic>? saved;
  int validations = 0;
  final route = <String, dynamic>{
    'id': 'route',
    'version': 1,
    'network': 'orange',
    'category': 'maxit',
    'offers': 8,
    'action': 'APP:MAXIT',
    'configured': true,
    'technical_validated_at': null,
    'operator_validated_at': null,
  };
  @override
  Future<List<Map<String, dynamic>>> campaigns() async => [];
  @override
  Future<void> saveCampaign(
    Map<String, dynamic> payload, {
    String? id,
    int? version,
  }) async {
    saved = payload;
  }

  @override
  Future<void> campaignStatus(
    Map<String, dynamic> campaign,
    String status, {
    String? reference,
  }) async {}
  @override
  Future<List<Map<String, dynamic>>> routes() async => [Map.of(route)];
  @override
  Future<void> validateRoute(
    Map<String, dynamic> route, {
    String? operatorReference,
  }) async {
    validations++;
    this.route['technical_validated_at'] = 'synthetic';
    if (operatorReference != null) {
      this.route['operator_validated_at'] = 'synthetic';
    }
  }
}

void main() {
  const offer = AdminOffer(
    id: 'stable-maxit-id',
    network: MobileNetwork.orange,
    service: OfferService.internet,
    operationType: OrderOperationType.internetSubscription,
    title: 'Pass semaine 750 Mo',
    catalogLabel: '750 Mo',
    sellingPrice: 800,
    details: ['750 Mo'],
    category: 'maxit',
    isActive: true,
    displayOrder: 1,
    importData: {'volume_data': '750', 'unite_data': 'MO'},
  );
  Future<void> size(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'a Max it offer is selected by ID; saving never activates or validates a campaign',
    (tester) async {
      await size(tester);
      final repository = BonusFake();
      await tester.pumpWidget(
        MaterialApp(
          home: CatalogCampaignsDialog(
            repository: repository,
            offers: const [offer],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Aucune campagne configurée'), findsOneWidget);
      await tester.tap(find.text('Nouvelle campagne'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<FilterChip>(find.byType(FilterChip))
            .every((c) => !c.selected),
        isTrue,
      );
      Future<void> fill(String label, String value) async {
        final field = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label,
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      await fill('Nom de la campagne', 'Bonus test MAXIT');
      await fill(
        'Début — AAAA-MM-JJ HH:mm (Africa/Abidjan)',
        '2030-01-01 00:00',
      );
      await fill('Fin — AAAA-MM-JJ HH:mm (Africa/Abidjan)', '2030-02-01 00:00');
      await fill('Bonus ajouté (%)', '200');
      await tester.ensureVisible(find.text('Mar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Pass semaine 750 Mo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pass semaine 750 Mo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer le brouillon'));
      await tester.pumpAndSettle();
      expect(repository.saved!['offers'], [
        {'offer_id': 'stable-maxit-id', 'base_volume_mb': 750},
      ]);
      expect(repository.saved!['weekdays'], [2]);
      expect(repository.saved!['bonus_value'], 200);
      expect(repository.saved!.containsKey('price'), isFalse);
      expect(repository.validations, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('technical validation never becomes an operator validation', (
    tester,
  ) async {
    await size(tester);
    final repository = BonusFake();
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogRoutesDialog(repository: repository, canValidate: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Validation opérateur nécessaire'), findsOneWidget);
    await tester.tap(find.text('Tester la génération'));
    await tester.pumpAndSettle();
    expect(repository.validations, 1);
    expect(repository.route['operator_validated_at'], isNull);
    expect(find.textContaining('Validé techniquement : oui'), findsOneWidget);
    expect(find.text('Validation opérateur nécessaire'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Manager consultation does not offer validation controls', (
    tester,
  ) async {
    await size(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogRoutesDialog(repository: BonusFake(), canValidate: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tester la génération'), findsNothing);
    expect(find.text('Valider chez l’opérateur'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
