import 'package:cabine_flow/core/services/customer_support_whatsapp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomerSupportWhatsApp', () {
    test('construit un lien general vers le support IzyTel', () {
      final Uri uri = CustomerSupportWhatsApp.buildUri();

      expect(uri.host, 'wa.me');
      expect(uri.path, '/2250152368290');
      expect(
        uri.queryParameters['text'],
        'Bonjour, j’ai besoin d’aide sur IzyTel.',
      );
    });

    test('inclut la reference de commande lorsqu elle est connue', () {
      final Uri uri = CustomerSupportWhatsApp.buildUri(
        orderReference: ' cf-20260827-abcd12 ',
      );

      expect(uri.path, '/2250152368290');
      expect(
        uri.queryParameters['text'],
        'Bonjour, j’ai besoin d’aide concernant ma commande CF-20260827-ABCD12 sur IzyTel.',
      );
    });
  });
}
