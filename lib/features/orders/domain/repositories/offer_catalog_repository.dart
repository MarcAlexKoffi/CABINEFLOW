import 'package:cabine_flow/features/orders/domain/models/offer_catalog_item.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

abstract class OfferCatalogRepository {
  Future<List<OfferCatalogItem>> fetchOffers({required MobileNetwork network});
}
