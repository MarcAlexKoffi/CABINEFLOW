import 'package:cabine_flow/features/customer_order/domain/models/customer_order_recovery_key.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 10B - clé de récupération', () {
    test('normalise et valide la référence réellement générée par IzyTel', () {
      expect(
        CustomerOrderRecoveryKey.normalizeReference(' cf-20260827-ab12cd '),
        'CF-20260827-AB12CD',
      );
      expect(
        CustomerOrderRecoveryKey.validateReference('CF-20260827-AB12CD'),
        isNull,
      );
    });

    test('refuse les anciens formats incomplets', () {
      expect(
        CustomerOrderRecoveryKey.validateReference('CF-2025-ABCD'),
        'Format invalide.',
      );
    });

    test('construit une clé exacte référence + WhatsApp normalisé', () {
      final WhatsappPhoneNumber phone = WhatsappPhoneNumber.parse(
        '07 12 34 56 78',
      );

      expect(
        CustomerOrderRecoveryKey.build(
          reference: 'cf-20260827-ab12cd',
          whatsappPhone: phone,
        ),
        'CF-20260827-AB12CD_+2250712345678',
      );
    });
  });
}
