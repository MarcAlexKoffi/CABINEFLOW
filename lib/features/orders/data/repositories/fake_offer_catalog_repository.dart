import 'package:cabine_flow/features/orders/domain/models/offer_catalog_item.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/offer_catalog_repository.dart';

class FakeOfferCatalogRepository implements OfferCatalogRepository {
  const FakeOfferCatalogRepository();

  @override
  Future<List<OfferCatalogItem>> fetchOffers({
    required MobileNetwork network,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    return _offers.where((OfferCatalogItem offer) {
      return offer.network == network;
    }).toList();
  }

  static const List<OfferCatalogItem> _offers = [
    OfferCatalogItem(
      id: 'orange-internet',
      network: MobileNetwork.orange,
      operationType: OrderOperationType.internetSubscription,
      label: 'Pass Internet Orange',
    ),
    OfferCatalogItem(
      id: 'orange-transfer',
      network: MobileNetwork.orange,
      operationType: OrderOperationType.unitTransfer,
      label: 'Transfert d’unités Orange',
    ),
    OfferCatalogItem(
      id: 'orange-call',
      network: MobileNetwork.orange,
      operationType: OrderOperationType.callBundle,
      label: 'Forfait appels Orange',
    ),
    OfferCatalogItem(
      id: 'orange-mixed',
      network: MobileNetwork.orange,
      operationType: OrderOperationType.mixedBundle,
      label: 'Forfait mixte Orange',
    ),

    OfferCatalogItem(
      id: 'mtn-internet',
      network: MobileNetwork.mtn,
      operationType: OrderOperationType.internetSubscription,
      label: 'Pass Internet MTN',
    ),
    OfferCatalogItem(
      id: 'mtn-transfer',
      network: MobileNetwork.mtn,
      operationType: OrderOperationType.unitTransfer,
      label: 'Transfert d’unités MTN',
    ),
    OfferCatalogItem(
      id: 'mtn-call',
      network: MobileNetwork.mtn,
      operationType: OrderOperationType.callBundle,
      label: 'Forfait appels MTN',
    ),
    OfferCatalogItem(
      id: 'mtn-mixed',
      network: MobileNetwork.mtn,
      operationType: OrderOperationType.mixedBundle,
      label: 'Forfait mixte MTN',
    ),

    OfferCatalogItem(
      id: 'moov-internet',
      network: MobileNetwork.moov,
      operationType: OrderOperationType.internetSubscription,
      label: 'Pass Internet Moov',
    ),
    OfferCatalogItem(
      id: 'moov-transfer',
      network: MobileNetwork.moov,
      operationType: OrderOperationType.unitTransfer,
      label: 'Transfert d’unités Moov',
    ),
    OfferCatalogItem(
      id: 'moov-call',
      network: MobileNetwork.moov,
      operationType: OrderOperationType.callBundle,
      label: 'Forfait appels Moov',
    ),
    OfferCatalogItem(
      id: 'moov-mixed',
      network: MobileNetwork.moov,
      operationType: OrderOperationType.mixedBundle,
      label: 'Forfait mixte Moov',
    ),
  ];
}
