import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

class CustomerOrderDraft {
  const CustomerOrderDraft({
    this.identity,
    this.service,
    this.network,
    this.offer,
    this.customOfferLabel,
    this.amount,
    this.beneficiaryNumber,
  });

  final CustomerIdentity? identity;
  final CustomerService? service;
  final MobileNetwork? network;
  final CustomerOffer? offer;

  /// Non-null when the customer chose to describe an offer that is not
  /// available in the public catalog. An empty string means that the custom
  /// offer mode is active but the field has not been completed yet.
  final String? customOfferLabel;

  final int? amount;

  /// Stored only after the two beneficiary fields have been validated and
  /// confirmed as identical.
  final BeneficiaryPhoneNumber? beneficiaryNumber;

  bool get usesCustomOffer => customOfferLabel != null;

  String? get selectedOfferLabel {
    if (service == CustomerService.unitTransfer) {
      return 'Transfert d’unités';
    }

    if (usesCustomOffer) {
      final String label = customOfferLabel!.trim();
      return label.isEmpty ? null : label;
    }

    return offer?.catalogLabel;
  }

  CustomerOrderDraft copyWith({
    CustomerIdentity? identity,
    CustomerService? service,
    MobileNetwork? network,
    CustomerOffer? offer,
    String? customOfferLabel,
    int? amount,
    BeneficiaryPhoneNumber? beneficiaryNumber,
    bool clearNetwork = false,
    bool clearOffer = false,
    bool clearCustomOfferLabel = false,
    bool clearAmount = false,
    bool clearBeneficiaryNumber = false,
  }) {
    return CustomerOrderDraft(
      identity: identity ?? this.identity,
      service: service ?? this.service,
      network: clearNetwork ? null : network ?? this.network,
      offer: clearOffer ? null : offer ?? this.offer,
      customOfferLabel: clearCustomOfferLabel
          ? null
          : customOfferLabel ?? this.customOfferLabel,
      amount: clearAmount ? null : amount ?? this.amount,
      beneficiaryNumber: clearBeneficiaryNumber
          ? null
          : beneficiaryNumber ?? this.beneficiaryNumber,
    );
  }
}
