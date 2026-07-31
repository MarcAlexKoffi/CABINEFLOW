import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

abstract class CustomerOfferRepository {
  Future<List<CustomerOffer>> fetchOffers({
    required CustomerService service,
    required MobileNetwork network,
  });
}
