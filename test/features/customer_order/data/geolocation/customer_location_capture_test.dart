import 'package:cabine_flow/features/customer_order/domain/models/customer_order_context.dart';
import 'package:cabine_flow/features/customer_order/domain/services/customer_geolocation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC4B - CustomerLocationCapture', () {
    test('une position accordee conserve source et ajoute les coordonnees', () {
      const CustomerOrderContextDraft initial = CustomerOrderContextDraft(
        sourceCode: 'QR-YAKRO-01',
      );
      final DateTime capturedAt = DateTime.utc(2026, 9, 27, 0, 30);

      final CustomerOrderContextDraft updated = CustomerLocationCapture.granted(
        latitude: 6.8276,
        longitude: -5.2893,
        accuracyMeters: 18,
        capturedAt: capturedAt,
      ).applyTo(initial);

      expect(updated.sourceCode, 'QR-YAKRO-01');
      expect(updated.locationStatus, CustomerLocationStatus.granted);
      expect(updated.latitude, 6.8276);
      expect(updated.longitude, -5.2893);
      expect(updated.accuracyMeters, 18);
      expect(updated.locationCapturedAt, capturedAt);
    });

    test('un refus efface la position sans effacer la source commerciale', () {
      final CustomerOrderContextDraft initial = CustomerLocationCapture.granted(
        latitude: 5.35,
        longitude: -4.01,
        accuracyMeters: 20,
      ).applyTo(
        const CustomerOrderContextDraft(sourceCode: 'AFFICHE-ABJ-01'),
      );

      final CustomerOrderContextDraft updated =
          const CustomerLocationCapture.denied().applyTo(initial);

      expect(updated.sourceCode, 'AFFICHE-ABJ-01');
      expect(updated.locationStatus, CustomerLocationStatus.denied);
      expect(updated.hasLocation, isFalse);
      expect(updated.latitude, isNull);
      expect(updated.longitude, isNull);
      expect(updated.accuracyMeters, isNull);
      expect(updated.locationCapturedAt, isNull);
    });
  });
}
