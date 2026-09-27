import 'package:cabine_flow/features/customer_order/domain/models/customer_order_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC4A - contexte commande client', () {
    test('la geolocalisation est absente tant que le consentement nest pas accorde', () {
      const CustomerOrderContextDraft context = CustomerOrderContextDraft(
        sourceCode: 'QR-YAKRO-01',
      );

      expect(context.sourceCode, 'QR-YAKRO-01');
      expect(context.locationStatus, CustomerLocationStatus.notRequested);
      expect(context.hasLocation, isFalse);
    });

    test('une position consentie est distinguee du code source', () {
      final CustomerOrderContextDraft context = CustomerOrderContextDraft(
        sourceCode: 'AFFICHE-001',
        locationStatus: CustomerLocationStatus.granted,
        latitude: 5.426208,
        longitude: -4.0159,
        accuracyMeters: 25,
        locationCapturedAt: DateTime.utc(2026, 9, 26),
      );

      expect(context.sourceCode, 'AFFICHE-001');
      expect(context.hasLocation, isTrue);
      expect(context.latitude, 5.426208);
    });
  });
}
