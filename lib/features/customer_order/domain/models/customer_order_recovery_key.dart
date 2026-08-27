import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';

class CustomerOrderRecoveryKey {
  const CustomerOrderRecoveryKey._();

  static final RegExp _referencePattern = RegExp(
    r'^CF-[0-9]{8}-[A-Z0-9]{4,12}$',
  );

  static String normalizeReference(String input) {
    return input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  static String? validateReference(String? input) {
    final String value = normalizeReference(input ?? '');

    if (value.isEmpty) {
      return 'Saisissez la référence de commande.';
    }

    if (!_referencePattern.hasMatch(value)) {
      return 'Format invalide.';
    }

    return null;
  }

  static String build({
    required String reference,
    required WhatsappPhoneNumber whatsappPhone,
  }) {
    final String normalizedReference = normalizeReference(reference);
    return '${normalizedReference}_${whatsappPhone.normalized}';
  }
}
