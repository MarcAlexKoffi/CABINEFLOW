import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WhatsappPhoneNumber', () {
    test('normalise un numéro ivoirien local', () {
      final WhatsappPhoneNumber phone =
          WhatsappPhoneNumber.parse('07 00 00 00 00');

      expect(phone.normalized, '+2250700000000');
      expect(phone.displayValue, '+225 07 00 00 00 00');
    });

    test('accepte un numéro déjà préfixé par +225', () {
      final WhatsappPhoneNumber phone =
          WhatsappPhoneNumber.parse('+225 05 12 34 56 78');

      expect(phone.normalized, '+2250512345678');
    });

    test('accepte les parenthèses et les tirets', () {
      final WhatsappPhoneNumber phone =
          WhatsappPhoneNumber.parse('(01) 23-45-67-89');

      expect(phone.normalized, '+2250123456789');
    });

    test('refuse un numéro incomplet', () {
      expect(
        WhatsappPhoneNumber.validate('07 00 00'),
        isNotNull,
      );
    });

    test('refuse un préfixe mobile non pris en charge', () {
      expect(
        WhatsappPhoneNumber.validate('02 00 00 00 00'),
        isNotNull,
      );
    });
  });
}
