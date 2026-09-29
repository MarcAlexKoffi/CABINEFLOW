import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Web client - navigation stable restauree', () {
    test('messagerie et recuperation sont de vraies routes Flutter', () {
      final String flow = File(
        'lib/features/customer_order/presentation/pages/customer_order_flow_page.dart',
      ).readAsStringSync();

      expect(flow, contains('unawaited(_pushMessagingRoute())'));
      expect(flow, contains("RouteSettings(name: '/customer/messaging')"));
      expect(flow, contains('unawaited(_pushRecoveryRoute())'));
      expect(flow, contains("RouteSettings(name: '/customer/recovery')"));
      expect(flow, contains('Navigator.of(routeContext).maybePop()'));
      expect(flow, contains('_messagingRouteActive || _recoveryRouteActive'));
      expect(flow, isNot(contains('_navigateTo(_CustomerSurface.messaging)')));
    });

    test('historique navigateur reste simple et ne concurrence pas les routes Flutter', () {
      final String history = File(
        'lib/core/navigation/customer_web_history_web.dart',
      ).readAsStringSync();

      expect(history, contains("static const String _marker = 'izytel_customer_web'"));
      expect(history, isNot(contains('_decodeHash')));
      expect(history, isNot(contains("'#/aide/messagerie")));
      expect(history, contains('html.window.location.href'));
    });

    test('Retrouver ma commande reste dans la categorie Aide sur mobile Web', () {
      final String recovery = File(
        'lib/features/customer_order/presentation/pages/customer_order_recovery_page.dart',
      ).readAsStringSync();
      expect(recovery, contains('current: IzyTelCustomerDestination.help'));
    });
  });
}
