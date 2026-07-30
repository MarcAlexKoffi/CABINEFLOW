import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

class OfferCatalogItem {
  const OfferCatalogItem({
    required this.id,
    required this.network,
    required this.operationType,
    required this.label,
    this.suggestedAmount,
    this.isCustom = false,
  });

  final String id;
  final MobileNetwork network;
  final OrderOperationType operationType;
  final String label;
  final int? suggestedAmount;
  final bool isCustom;

  factory OfferCatalogItem.custom({
    required MobileNetwork network,
    required OrderOperationType operationType,
  }) {
    return OfferCatalogItem(
      id: 'custom-${network.name}-${operationType.name}',
      network: network,
      operationType: operationType,
      label: 'Autre offre / saisie manuelle',
      isCustom: true,
    );
  }
}
