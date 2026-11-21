import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/domain/entities/offers/offer_bonus.dart';

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
    this.category,
    this.bonus,
    this.operationType,
  });

  final String id;
  final MobileNetwork network;
  final CustomerOfferType type;
  final String title;
  final String catalogLabel;
  final int amount;
  final List<String> details;
  final String? badgeLabel;
  final String? category;
  final OfferBonus? bonus;
  final OrderOperationType? operationType;
  String? get displayBadge =>
      bonus?.visible == true ? bonus!.badge : badgeLabel;
  List<String> get displayDetails => bonus?.visible == true
      ? [
          'Volume habituel : ${OfferBonus.volume(bonus!.baseVolumeMb)}',
          'Volume total : ${OfferBonus.volume(bonus!.totalVolumeMb)}',
          ...details,
        ]
      : details;
  String get categoryLabel => switch (category) {
    'maxit' => 'MAXIT',
    'cchic' => "C’CHIC",
    'folie' => 'Folie',
    'mixed' => 'Mixte',
    'calls' => 'Appel',
    _ => type == CustomerOfferType.calls ? 'Appels' : 'Internet',
  };
  CustomerOffer withBonus(OfferBonus? value) => CustomerOffer(
    id: id,
    network: network,
    type: type,
    title: title,
    catalogLabel: catalogLabel,
    amount: amount,
    details: details,
    badgeLabel: badgeLabel,
    category: category,
    bonus: value,
    operationType: operationType,
  );
}
