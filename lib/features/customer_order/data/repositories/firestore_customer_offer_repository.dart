import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_offer_repository.dart';
import 'package:cabine_flow/features/offers/data/models/firestore_offer_data.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreCustomerOfferRepository implements CustomerOfferRepository {
  FirestoreCustomerOfferRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _offersCollection {
    return _firestore.collection('offers');
  }

  @override
  Future<List<CustomerOffer>> fetchOffers({
    required CustomerService service,
    required MobileNetwork network,
  }) async {
    final CustomerOfferType? expectedType = switch (service) {
      CustomerService.internetSubscription => CustomerOfferType.internet,
      CustomerService.calls => CustomerOfferType.calls,
      CustomerService.unitTransfer => null,
    };

    if (expectedType == null) {
      return const <CustomerOffer>[];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _offersCollection
        .where('isActive', isEqualTo: true)
        .get();

    final List<_CustomerOfferWithOrder> offers = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> document) {
          final FirestoreOfferData? data = FirestoreOfferData.tryParse(
            id: document.id,
            data: document.data(),
          );

          if (data == null || !data.isActive) {
            return null;
          }

          if (data.network != network.name || data.service != service.name) {
            return null;
          }

          return _CustomerOfferWithOrder(
            displayOrder: data.displayOrder,
            offer: CustomerOffer(
              id: data.id,
              network: network,
              type: expectedType,
              title: data.title,
              catalogLabel: data.catalogLabel,
              amount: data.sellingPrice,
              details: data.details,
              badgeLabel: data.badgeLabel,
            ),
          );
        })
        .whereType<_CustomerOfferWithOrder>()
        .toList();

    offers.sort((
      _CustomerOfferWithOrder first,
      _CustomerOfferWithOrder second,
    ) {
      final int orderComparison = first.displayOrder.compareTo(
        second.displayOrder,
      );

      if (orderComparison != 0) {
        return orderComparison;
      }

      return first.offer.amount.compareTo(second.offer.amount);
    });

    return List<CustomerOffer>.unmodifiable(
      offers.map((_CustomerOfferWithOrder item) => item.offer),
    );
  }
}

class _CustomerOfferWithOrder {
  const _CustomerOfferWithOrder({
    required this.displayOrder,
    required this.offer,
  });

  final int displayOrder;
  final CustomerOffer offer;
}
