import 'package:cabine_flow/app/domain/entities/orders/offer_catalog_item.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';

abstract class OfferCatalogRepository {
  Future<List<OfferCatalogItem>> fetchOffers({required MobileNetwork network});

  /// Flux réactif du catalogue Staff pour le réseau courant.
  ///
  /// Les repositories legacy/fake restent compatibles via ce fallback
  /// one-shot. Supabase le surcharge pour suivre les changements BO-4.
  Stream<List<OfferCatalogItem>> watchOffers({
    required MobileNetwork network,
  }) async* {
    yield await fetchOffers(network: network);
  }
}
