import 'package:cabine_flow/app/data/repositories/fake_customer_offer_repository.dart';
import 'package:cabine_flow/app/domain/entities/customer/customer_offer.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/modules/customer/views/customer_catalog_page.dart';
import 'package:cabine_flow/app/theme/customer_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../support/catalog_visual_fonts.dart';

class _PresentationOffers extends FakeCustomerOfferRepository {
  @override
  Stream<List<CustomerOffer>> watchAllOffers() => Stream.value(const [
    CustomerOffer(
      id: 'maxit',
      network: MobileNetwork.orange,
      type: CustomerOfferType.internet,
      title: '1,5 GO',
      catalogLabel: '1,5 GO',
      amount: 1000,
      badgeLabel: 'Pass Max it',
      details: ['1,5 GO', 'Validité 3 jours'],
    ),
    CustomerOffer(
      id: 'decimal',
      network: MobileNetwork.mtn,
      type: CustomerOfferType.internet,
      title: '2,2 GO',
      catalogLabel: '2,2 GO',
      amount: 1500,
      details: ['Packs Internet · 2,2 GO', 'Validité 10 jours'],
    ),
    CustomerOffer(
      id: 'classics',
      network: MobileNetwork.moov,
      type: CustomerOfferType.internet,
      title: '1,5 GO',
      catalogLabel: '1,5 GO',
      amount: 1000,
      badgeLabel: 'Internet Classics',
      details: ['1,5 GO', 'Validité 5 jours'],
    ),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ThemeData theme;
  setUpAll(() async {
    await catalogVisualTheme();
    theme = CustomerAppTheme.light;
    await GoogleFonts.pendingFonts();
  });
  for (final width in [320.0, 390.0, 930.0, 1440.0]) {
    testWidgets(
      'unchanged customer cards show commercial nature and 2,2 GO at $width px',
      (tester) async {
        tester.view.physicalSize = Size(width, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: CustomerCatalogPage(
              offerRepository: _PresentationOffers(),
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
        for (final text in [
          'Pass Max it',
          'Internet Classics',
          'Packs Internet · 2,2 GO',
          'Validité 10 jours',
        ]) {
          expect(find.text(text), findsOneWidget);
        }
        expect(find.textContaining('2.2000000000000002'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
