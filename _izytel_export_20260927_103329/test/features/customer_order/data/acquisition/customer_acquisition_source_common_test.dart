import 'package:cabine_flow/features/customer_order/data/acquisition/customer_acquisition_source_common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC4A - source acquisition', () {
    test('normalise un code QR/campagne sans en faire une zone', () {
      expect(
        normalizeCustomerAcquisitionSourceCode(' qr-yakro-01 '),
        'QR-YAKRO-01',
      );
    });

    test('refuse un code vide, trop long ou contenant des caracteres libres', () {
      expect(normalizeCustomerAcquisitionSourceCode(''), isNull);
      expect(normalizeCustomerAcquisitionSourceCode('QR YAKRO'), isNull);
      expect(
        normalizeCustomerAcquisitionSourceCode(List<String>.filled(65, 'A').join()),
        isNull,
      );
    });
  });
}
