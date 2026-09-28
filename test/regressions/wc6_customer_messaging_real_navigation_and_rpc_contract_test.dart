import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC6 - Messagerie Client navigation reelle et RPC Web', () {
    test('le retour navigateur mobile utilise une vraie route Flutter', () {
      final String flow = File(
        'lib/features/customer_order/presentation/pages/customer_order_flow_page.dart',
      ).readAsStringSync();
      final String messaging = File(
        'lib/features/messaging/presentation/pages/customer_messaging_page.dart',
      ).readAsStringSync();

      expect(flow, contains('_pushMessagingRoute'));
      expect(flow, contains("RouteSettings(name: '/customer/messaging')"));
      expect(flow, contains('Navigator.of(routeContext).maybePop()'));
      expect(messaging, contains("RouteSettings(name: '/customer/messaging/new')"));
      expect(messaging, contains("'/customer/messaging/conversation/"));
      expect(messaging, isNot(contains('PopScope(')));
      expect(messaging, contains('widget.onBack();'));
    });

    test('le CTA nouvelle conversation est lisible et premium', () {
      final String messaging = File(
        'lib/features/messaging/presentation/pages/customer_messaging_page.dart',
      ).readAsStringSync();

      expect(messaging, contains('_PremiumNewConversationButton'));
      expect(messaging, contains('Icons.add_rounded'));
      expect(messaging, contains('color: Colors.white'));
      expect(messaging, contains('CustomerAppColors.primarySoft'));
      expect(messaging, contains('FilledButton.icon'));
    });

    test('les RPC Web Client exposes au JWT Firebase sont documentes localement', () {
      final String publicMigration = File(
        'supabase/migrations/20260927152551_wc6_customer_web_rpc_execute_fix.sql',
      ).readAsStringSync();
      final String privateMigration = File(
        'supabase/migrations/20260927154513_wc6_customer_private_rpc_execute_fix.sql',
      ).readAsStringSync();

      expect(publicMigration, contains('izytel_wc5_create_conversation'));
      expect(publicMigration, contains('izytel_wc2_customer_order_history'));
      expect(publicMigration, contains('to anon, authenticated, service_role'));
      expect(privateMigration, contains('private.izytel_wc5_create_conversation'));
      expect(privateMigration, contains('private.izytel_wc2_customer_order_history'));
      expect(privateMigration, contains('to anon, authenticated, service_role'));
    });
  });
}
