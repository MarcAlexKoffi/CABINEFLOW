import 'dart:math';

import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';

class CustomerOrderRecoveryKey {
  const CustomerOrderRecoveryKey._();

  static final RegExp _referencePattern = RegExp(
    r'^CF-[0-9]{8}-[A-Z0-9]{4,12}$',
  );
  static final RegExp _recoveryCodePattern = RegExp(
    r'^IZY-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$',
  );
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

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

  static String normalizeCode(String input) {
    final String token = input
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '');
    final String compact = token.replaceAll('-', '');
    if (compact.length == 11 && compact.startsWith('IZY')) {
      return 'IZY-${compact.substring(3, 7)}-${compact.substring(7)}';
    }
    return token;
  }

  static String? validateCode(String? input) {
    final String value = normalizeCode(input ?? '');

    if (value.isEmpty) {
      return 'Saisissez le code de récupération.';
    }

    if (!_recoveryCodePattern.hasMatch(value)) {
      return 'Code de récupération invalide.';
    }

    return null;
  }

  static String generateCode({Random? random}) {
    final Random generator = random ?? Random.secure();
    final StringBuffer buffer = StringBuffer('IZY-');

    for (int index = 0; index < 8; index++) {
      if (index == 4) buffer.write('-');
      buffer.write(_alphabet[generator.nextInt(_alphabet.length)]);
    }

    return buffer.toString();
  }

  static String buildWithCode({
    required String reference,
    required String recoveryCode,
  }) {
    final String normalizedReference = normalizeReference(reference);
    final String normalizedCode = normalizeCode(recoveryCode);
    return '${normalizedReference}_$normalizedCode';
  }

  // Compatibilite Phase 10B historique. Les nouvelles interfaces client ne
  // doivent plus utiliser le WhatsApp comme secret de recuperation.
  static String build({
    required String reference,
    required WhatsappPhoneNumber whatsappPhone,
  }) {
    final String normalizedReference = normalizeReference(reference);
    return '${normalizedReference}_${whatsappPhone.normalized}';
  }
}
