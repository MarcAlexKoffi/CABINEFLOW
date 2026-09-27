import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

enum CustomerOfferType { internet, calls }

class CustomerOffer {
  const CustomerOffer({
    required this.id,
    required this.network,
    required this.type,
    required this.title,
    required this.catalogLabel,
    required this.amount,
    required this.details,
    this.badgeLabel,
  });

  final String id;
  final MobileNetwork network;
  final CustomerOfferType type;
  final String title;
  final String catalogLabel;
  final int amount;
  final List<String> details;
  final String? badgeLabel;
}
