import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const FakeCustomerOfferRepository repository = FakeCustomerOfferRepository();

  group('FakeCustomerOfferRepository', () {
    test('retourne uniquement les offres Internet Orange', () async {
      final List<CustomerOffer> offers = await repository.fetchOffers(
        service: CustomerService.internetSubscription,
        network: MobileNetwork.orange,
      );

      expect(offers, hasLength(6));
      expect(
        offers.every((CustomerOffer offer) {
          return offer.network == MobileNetwork.orange &&
              offer.type == CustomerOfferType.internet;
        }),
        isTrue,
      );
    });

    test('retourne uniquement les forfaits d’appels Moov', () async {
      final List<CustomerOffer> offers = await repository.fetchOffers(
        service: CustomerService.calls,
        network: MobileNetwork.moov,
      );

      expect(offers, hasLength(5));
      expect(
        offers.every((CustomerOffer offer) {
          return offer.network == MobileNetwork.moov &&
              offer.type == CustomerOfferType.calls;
        }),
        isTrue,
      );
    });

    test('ne retourne aucune offre pour le transfert d’unités', () async {
      final List<CustomerOffer> offers = await repository.fetchOffers(
        service: CustomerService.unitTransfer,
        network: MobileNetwork.mtn,
      );

      expect(offers, isEmpty);
    });

    test(
      'n’expose pas les offres MTN C’CHIC dans le catalogue public',
      () async {
        final List<CustomerOffer> offers = await repository.fetchOffers(
          service: CustomerService.internetSubscription,
          network: MobileNetwork.mtn,
        );

        expect(
          offers.any((CustomerOffer offer) {
            return offer.catalogLabel.toLowerCase().contains('chic');
          }),
          isFalse,
        );
      },
    );
  });
}
