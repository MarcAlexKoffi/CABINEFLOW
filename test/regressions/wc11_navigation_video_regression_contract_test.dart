import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WC11 - un geste Retour reste verrouille 250 ms dans les shells mobiles', () {
    final String shell = File(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    ).readAsStringSync();
    final String partner = File(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    ).readAsStringSync();

    expect(
      RegExp(r'Duration\(milliseconds: 250\)').allMatches(shell).length,
      greaterThanOrEqualTo(2),
    );
    expect(shell, contains('_handlingSystemBack = true'));
    expect(shell, contains('_handlingSystemBack = false'));
    expect(partner, contains('Duration(milliseconds: 250)'));
  });

  test('WC11 - Web restaure la messagerie route et ajoute recovery route', () {
    final String flow = File(
      'lib/features/customer_order/presentation/pages/customer_order_flow_page.dart',
    ).readAsStringSync();

    expect(flow, contains("RouteSettings(name: '/customer/messaging')"));
    expect(flow, contains("RouteSettings(name: '/customer/recovery')"));
    expect(flow, contains('_messagingRouteActive || _recoveryRouteActive'));
    expect(flow, contains('unawaited(_pushMessagingRoute())'));
    expect(flow, contains('unawaited(_pushRecoveryRoute())'));
  });
}
