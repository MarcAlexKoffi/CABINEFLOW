import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

class AdminOffer {
  const AdminOffer({
    required this.id,
    required this.network,
    required this.service,
    required this.operationType,
    required this.title,
    required this.catalogLabel,
    required this.sellingPrice,
    required this.details,
    required this.category,
    required this.isActive,
    required this.displayOrder,
    this.description,
    this.badgeLabel,
    this.validity,
    this.volume,
    this.minutes,
    this.sms,
    this.eligibility,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final MobileNetwork network;
  final OfferService service;
  final OrderOperationType operationType;
  final String title;
  final String catalogLabel;
  final int sellingPrice;
  final List<String> details;
  final String category;
  final bool isActive;
  final int displayOrder;
  final String? description;
  final String? badgeLabel;
  final String? validity;
  final String? volume;
  final String? minutes;
  final String? sms;
  final String? eligibility;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AdminOffer copyWith({
    MobileNetwork? network,
    OfferService? service,
    OrderOperationType? operationType,
    String? title,
    String? catalogLabel,
    int? sellingPrice,
    List<String>? details,
    String? category,
    bool? isActive,
    int? displayOrder,
    String? description,
    String? badgeLabel,
    String? validity,
    String? volume,
    String? minutes,
    String? sms,
    String? eligibility,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminOffer(
      id: id,
      network: network ?? this.network,
      service: service ?? this.service,
      operationType: operationType ?? this.operationType,
      title: title ?? this.title,
      catalogLabel: catalogLabel ?? this.catalogLabel,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      details: details ?? this.details,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      description: description ?? this.description,
      badgeLabel: badgeLabel ?? this.badgeLabel,
      validity: validity ?? this.validity,
      volume: volume ?? this.volume,
      minutes: minutes ?? this.minutes,
      sms: sms ?? this.sms,
      eligibility: eligibility ?? this.eligibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum OfferService { internet, calls }

extension OfferServiceX on OfferService {
  String get firestoreValue {
    switch (this) {
      case OfferService.internet:
        return 'internetSubscription';
      case OfferService.calls:
        return 'calls';
    }
  }

  String get label {
    switch (this) {
      case OfferService.internet:
        return 'Internet';
      case OfferService.calls:
        return 'Appels';
    }
  }
}

class AdminOfferDraft {
  const AdminOfferDraft({
    required this.network,
    required this.service,
    required this.operationType,
    required this.title,
    required this.catalogLabel,
    required this.sellingPrice,
    required this.details,
    required this.category,
    required this.isActive,
    required this.displayOrder,
    this.description,
    this.badgeLabel,
    this.validity,
    this.volume,
    this.minutes,
    this.sms,
    this.eligibility,
  });

  final MobileNetwork network;
  final OfferService service;
  final OrderOperationType operationType;
  final String title;
  final String catalogLabel;
  final int sellingPrice;
  final List<String> details;
  final String category;
  final bool isActive;
  final int displayOrder;
  final String? description;
  final String? badgeLabel;
  final String? validity;
  final String? volume;
  final String? minutes;
  final String? sms;
  final String? eligibility;
}
