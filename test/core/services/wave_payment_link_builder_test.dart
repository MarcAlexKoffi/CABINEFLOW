import 'package:cabine_flow/core/services/wave_payment_link_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WavePaymentLinkBuilder', () {
    const WavePaymentLinkBuilder builder = WavePaymentLinkBuilder();

    test('génère le lien Wave avec le montant demandé', () {
      final Uri uri = builder.build(amount: 2020);

      expect(
        uri.toString(),
        'https://pay.wave.com/'
        'm/M_vv7V2SMbMiki/c/ci/'
        '?amount=2020',
      );
    });

    test('refuse un montant égal à zéro', () {
      expect(() {
        builder.build(amount: 0);
      }, throwsArgumentError);
    });

    test('refuse un montant négatif', () {
      expect(() {
        builder.build(amount: -500);
      }, throwsArgumentError);
    });
  });
}
