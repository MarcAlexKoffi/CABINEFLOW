import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

abstract class CustomerOfferRepository {
  Future<List<CustomerOffer>> fetchOffers({
    required CustomerService service,
    required MobileNetwork network,
  });

  /// Flux réactif du sous-catalogue demandé.
  ///
  /// Les implémentations historiques restent compatibles grâce à ce fallback
  /// one-shot. Supabase le surcharge pour émettre à chaque mutation du
  /// catalogue canonique.
  Stream<List<CustomerOffer>> watchOffers({
    required CustomerService service,
    required MobileNetwork network,
  }) async* {
    yield await fetchOffers(service: service, network: network);
  }

  /// Flux réactif de toutes les offres client visibles.
  ///
  /// Le fallback agrège les deux services supportés pour les trois réseaux.
  Stream<List<CustomerOffer>> watchAllOffers() async* {
    final List<List<CustomerOffer>> groups = await Future.wait(
      <Future<List<CustomerOffer>>>[
        for (final MobileNetwork network in MobileNetwork.values)
          ...<Future<List<CustomerOffer>>>[
            fetchOffers(
              service: CustomerService.internetSubscription,
              network: network,
            ),
            fetchOffers(service: CustomerService.calls, network: network),
          ],
      ],
    );
    yield List<CustomerOffer>.unmodifiable(groups.expand((items) => items));
  }
}
