import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_catalog_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_offer_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'catalogue: Reessayer puis filtres Internet/Appels et trois reseaux',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Offers();
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerCatalogPage(
            offerRepository: repository,
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
      expect(
        find.text('Impossible de charger les offres pour le moment.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      for (final type in CustomerOfferType.values) {
        await tester.tap(
          find.widgetWithText(
            ChoiceChip,
            type == CustomerOfferType.internet ? 'Internet' : 'Appels',
          ),
        );
        await tester.pump();
        for (final network in MobileNetwork.values) {
          final label = switch (network) {
            MobileNetwork.orange => 'Orange',
            MobileNetwork.mtn => 'MTN',
            MobileNetwork.moov => 'Moov Africa',
          };
          await tester.tap(find.widgetWithText(ChoiceChip, label));
          await tester.pump();
          expect(
            find.text('test-${network.name}-${type.name}'),
            findsOneWidget,
          );
          for (final other in MobileNetwork.values.where(
            (value) => value != network,
          )) {
            expect(find.text('test-${other.name}-${type.name}'), findsNothing);
          }
        }
      }
      expect(repository.calls, 2, reason: 'filters reuse the loaded catalogue');
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'selection offre: le message erreur propose aussi un vrai reessai',
    (tester) async {
      final repository = _Offers();
      final viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
      );
      viewModel.selectService(CustomerService.internetSubscription);
      viewModel.selectNetwork(MobileNetwork.orange);
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerOfferPage(
            viewModel: viewModel,
            offerRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Réessayer'));
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(find.text('test-orange-internet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      viewModel.dispose();
    },
  );
}

class _Offers extends FakeCustomerOfferRepository {
  int calls = 0;
  @override
  Stream<List<CustomerOffer>> watchAllOffers() {
    if (++calls == 1) return Stream.error(StateError('test failure'));
    return Stream.value([
      for (final network in MobileNetwork.values)
        for (final type in CustomerOfferType.values)
          CustomerOffer(
            id: '${network.name}-${type.name}',
            network: network,
            type: type,
            title: 'test-${network.name}-${type.name}',
            catalogLabel: 'Test catalogue',
            amount: 500,
            details: const ['Test'],
          ),
    ]);
  }

  @override
  Stream<List<CustomerOffer>> watchOffers({
    required CustomerService service,
    required MobileNetwork network,
  }) {
    return watchAllOffers().map(
      (offers) => offers
          .where(
            (offer) =>
                offer.network == network &&
                offer.type ==
                    (service == CustomerService.calls
                        ? CustomerOfferType.calls
                        : CustomerOfferType.internet),
          )
          .toList(),
    );
  }
}
