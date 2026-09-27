import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/offers/data/repositories/fake_admin_offer_repository.dart';
import 'package:cabine_flow/features/offers/domain/models/admin_offer.dart';
import 'package:cabine_flow/features/offers/presentation/pages/offer_management_page.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche les cartes des offres chargees', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FakeAdminOfferRepository repository = FakeAdminOfferRepository(
      initialOffers: <AdminOffer>[
        const AdminOffer(
          id: 'orange-internet-1000',
          network: MobileNetwork.orange,
          service: OfferService.internet,
          operationType: OrderOperationType.internetSubscription,
          title: 'Internet Orange 4 Go',
          catalogLabel: 'Internet Orange 4 Go - 7 jours',
          sellingPrice: 1000,
          details: <String>[],
          category: 'internet',
          isActive: true,
          displayOrder: 1,
          validity: '7 jours',
          volume: '4 Go',
        ),
      ],
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: OfferManagementPage(
          user: const AppUser(
            id: 'admin-1',
            name: 'Marc',
            phoneNumber: '',
            role: UserRole.administrator,
          ),
          repository: repository,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('34'), findsNothing);
    expect(find.text('1 offre'), findsOneWidget);
    expect(find.text('Internet Orange 4 Go'), findsOneWidget);
    expect(find.text('1 000 F'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });
}
