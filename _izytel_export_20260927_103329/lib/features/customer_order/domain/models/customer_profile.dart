import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';

class CustomerProfile {
  const CustomerProfile({
    required this.name,
    required this.whatsappPhone,
    required this.defaultBeneficiaryPhone,
  });

  final String name;
  final WhatsappPhoneNumber whatsappPhone;
  final BeneficiaryPhoneNumber defaultBeneficiaryPhone;

  bool matchesIdentity(CustomerIdentity identity) {
    return whatsappPhone.normalized == identity.whatsappNumber.normalized;
  }
}
