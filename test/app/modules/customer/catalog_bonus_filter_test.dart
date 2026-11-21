import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cabine_flow/app/data/repositories/fake_customer_offer_repository.dart';
import 'package:cabine_flow/app/domain/entities/customer/customer_offer.dart';
import 'package:cabine_flow/app/domain/entities/offers/offer_bonus.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/modules/customer/views/customer_catalog_page.dart';

class _Offers extends FakeCustomerOfferRepository {
  const _Offers(this.values);
  final List<CustomerOffer> values;
  @override
  Stream<List<CustomerOffer>> watchAllOffers() => Stream.value(values);
}

void main() {
  testWidgets(
    'the migrated offer appears only under MAXIT and loses an expired cached bonus',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var elapsed = Duration.zero;
      final maxit = CustomerOffer(
        id: 'stable-maxit',
        network: MobileNetwork.orange,
        type: CustomerOfferType.internet,
        title: 'Pass semaine 750 Mo',
        catalogLabel: '750 Mo',
        amount: 800,
        details: const ['750 Mo'],
        category: 'maxit',
        bonus: OfferBonus(
          baseVolumeMb: 750,
          totalVolumeMb: 2250,
          kind: 'percentage',
          value: 200,
          lease: const Duration(seconds: 5),
          elapsed: () => elapsed,
        ),
      );
      const internet = CustomerOffer(
        id: 'internet',
        network: MobileNetwork.orange,
        type: CustomerOfferType.internet,
        title: 'Pass Internet classique',
        catalogLabel: '1 Go',
        amount: 1000,
        details: ['1 Go'],
        category: 'internet',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerCatalogPage(
            offerRepository: _Offers([maxit, internet]),
            onBack: () {},
            onChooseOffer: (_) {},
            onStartOrder: () {},
            onStartDirectTransfer: () {},
            onOpenHome: () {},
            onOpenHistory: () {},
            onOpenHelp: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final internetChip = find.widgetWithText(ChoiceChip, 'Internet');
      await tester.ensureVisible(internetChip);
      await tester.pumpAndSettle();
      await tester.tap(internetChip);
      await tester.pumpAndSettle();
      expect(find.text('Pass Internet classique'), findsOneWidget);
      expect(find.text('Pass semaine 750 Mo'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'MAXIT'));
      await tester.pumpAndSettle();
      expect(find.text('Pass semaine 750 Mo'), findsOneWidget);
      expect(find.text('Pass Internet classique'), findsNothing);
      expect(find.text('Volume total : 2,25 Go'), findsOneWidget);
      expect(find.text('+200 % de bonus'), findsOneWidget);
      elapsed = const Duration(seconds: 5);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('+200 % de bonus'), findsNothing);
      expect(find.text('Volume total : 2,25 Go'), findsNothing);
      expect(maxit.amount, 800);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
