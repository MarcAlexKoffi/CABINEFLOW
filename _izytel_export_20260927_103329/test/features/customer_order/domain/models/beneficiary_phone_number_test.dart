import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BeneficiaryPhoneNumber', () {
    test('normalise un numéro local ivoirien', () {
      final BeneficiaryPhoneNumber number = BeneficiaryPhoneNumber.parse(
        '07 12 34 56 78',
      );

      expect(number.normalized, '+2250712345678');
      expect(number.localDigits, '0712345678');
      expect(number.displayValue, '+225 07 12 34 56 78');
    });

    test('accepte un numéro déjà préfixé par +225', () {
      final BeneficiaryPhoneNumber number = BeneficiaryPhoneNumber.parse(
        '+225 05 98 76 54 32',
      );

      expect(number.normalized, '+2250598765432');
      expect(number.displayValue, '+225 05 98 76 54 32');
    });

    test('accepte le préfixe international 00225', () {
      final BeneficiaryPhoneNumber number = BeneficiaryPhoneNumber.parse(
        '00225 01 02 03 04 05',
      );

      expect(number.normalized, '+2250102030405');
    });

    test('déduit le réseau historique à partir du préfixe', () {
      expect(
        BeneficiaryPhoneNumber.parse('07 12 34 56 78').expectedNetwork,
        MobileNetwork.orange,
      );
      expect(
        BeneficiaryPhoneNumber.parse('05 12 34 56 78').expectedNetwork,
        MobileNetwork.mtn,
      );
      expect(
        BeneficiaryPhoneNumber.parse('01 12 34 56 78').expectedNetwork,
        MobileNetwork.moov,
      );
    });

    test('refuse un préfixe mobile non pris en charge', () {
      expect(BeneficiaryPhoneNumber.validate('03 12 34 56 78'), isNotNull);
    });

    test('refuse un numéro trop court', () {
      expect(BeneficiaryPhoneNumber.validate('07 12 34'), isNotNull);
    });
  });
}
