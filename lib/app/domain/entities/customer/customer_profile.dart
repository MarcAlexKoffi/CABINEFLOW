import 'package:cabine_flow/app/domain/entities/customer/beneficiary_phone_number.dart';
import 'package:cabine_flow/app/domain/entities/customer/customer_identity.dart';
import 'package:cabine_flow/app/domain/entities/customer/whatsapp_phone_number.dart';

class CustomerProfile {
  const CustomerProfile({
    required this.name,
    required this.defaultBeneficiaryPhone,
    this.whatsappPhone,
  });

  final String name;
  @Deprecated('Compatibilite historique uniquement.')
  final WhatsappPhoneNumber? whatsappPhone;
  final BeneficiaryPhoneNumber defaultBeneficiaryPhone;

  bool matchesIdentity(CustomerIdentity identity) {
    final WhatsappPhoneNumber? legacyIdentityPhone = identity.whatsappNumber;
    return legacyIdentityPhone != null &&
        whatsappPhone?.normalized == legacyIdentityPhone.normalized;
  }
}
