import 'package:cabine_flow/features/customer_order/domain/models/payment_declaration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentDeclaration', () {
    test('normalise les informations saisies par le client', () {
      final PaymentDeclaration declaration = PaymentDeclaration.parse(
        waveAccountName: '  Alex   Koffi  ',
        wavePayerPhoneInput: '07 00 00 00 00',
        approximatePaymentTime: '19:25',
        declaredWaveReference: '  WAVE-ABC-123  ',
      );

      expect(declaration.waveAccountName, 'Alex Koffi');
      expect(declaration.wavePayerPhone.normalized, '+2250700000000');
      expect(declaration.approximatePaymentTime, '19:25');
      expect(declaration.declaredWaveReference, 'WAVE-ABC-123');
    });

    test('accepte une référence vide comme valeur facultative', () {
      final PaymentDeclaration declaration = PaymentDeclaration.parse(
        waveAccountName: 'Alex Koffi',
        wavePayerPhoneInput: '05 00 00 00 00',
        approximatePaymentTime: '08:05',
        declaredWaveReference: '   ',
      );

      expect(declaration.declaredWaveReference, isNull);
    });

    test('refuse une heure approximative invalide', () {
      expect(
        () => PaymentDeclaration.parse(
          waveAccountName: 'Alex Koffi',
          wavePayerPhoneInput: '01 00 00 00 00',
          approximatePaymentTime: '25:80',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
