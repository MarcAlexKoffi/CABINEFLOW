import 'package:cabine_flow/features/offers/data/models/firestore_offer_data.dart';
import 'package:cabine_flow/features/orders/domain/models/offer_catalog_item.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/offer_catalog_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreOfferCatalogRepository implements OfferCatalogRepository {
  FirestoreOfferCatalogRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _offersCollection {
    return _firestore.collection('offers');
  }

  @override
  Future<List<OfferCatalogItem>> fetchOffers({
    required MobileNetwork network,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _offersCollection
        .where('isActive', isEqualTo: true)
        .get();

    final List<_CatalogOfferWithOrder> offers = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> document) {
          final FirestoreOfferData? data = FirestoreOfferData.tryParse(
            id: document.id,
            data: document.data(),
          );

          if (data == null || !data.isActive || data.network != network.name) {
            return null;
          }

          final OrderOperationType? operationType = _operationTypeFrom(
            data.operationType,
          );

          if (operationType == null) {
            return null;
          }

          return _CatalogOfferWithOrder(
            displayOrder: data.displayOrder,
            offer: OfferCatalogItem(
              id: data.id,
              network: network,
              operationType: operationType,
              label: data.catalogLabel,
              suggestedAmount: data.sellingPrice,
            ),
          );
        })
        .whereType<_CatalogOfferWithOrder>()
        .toList();

    offers.sort((_CatalogOfferWithOrder first, _CatalogOfferWithOrder second) {
      final int orderComparison = first.displayOrder.compareTo(
        second.displayOrder,
      );

      if (orderComparison != 0) {
        return orderComparison;
      }

      return (first.offer.suggestedAmount ?? 0).compareTo(
        second.offer.suggestedAmount ?? 0,
      );
    });

    return List<OfferCatalogItem>.unmodifiable(
      offers.map((_CatalogOfferWithOrder item) => item.offer),
    );
  }

  OrderOperationType? _operationTypeFrom(String value) {
    for (final OrderOperationType type in OrderOperationType.values) {
      if (type.name == value) {
        return type;
      }
    }

    return null;
  }
}

class _CatalogOfferWithOrder {
  const _CatalogOfferWithOrder({
    required this.displayOrder,
    required this.offer,
  });

  final int displayOrder;
  final OfferCatalogItem offer;
}
