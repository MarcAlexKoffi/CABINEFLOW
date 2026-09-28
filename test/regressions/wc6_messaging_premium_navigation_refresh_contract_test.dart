import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC6 - Messagerie premium navigation actualisation', () {
    test('client: retour interne et pull-to-refresh sur listes et fil', () {
      final String source = File(
        'lib/features/messaging/presentation/pages/customer_messaging_page.dart',
      ).readAsStringSync();

      expect(source, contains("RouteSettings(name: '/customer/messaging/new')"));
      expect(source, contains('_pushMobileConversationRoute'));
      expect(source, isNot(contains('PopScope(')));
      expect(source, contains('_refreshConversationsOnce'));
      expect(source, contains('_refreshMessagesOnce'));
      expect(source, contains('AlwaysScrollableScrollPhysics'));
      expect(source, contains('Assistance IzyTel'));
      expect(source, contains('Manager de votre zone'));
      expect(source, isNot(contains('wa.me')));
    });

    test('staff: boîte zonée, retour conversation et actualisation réelle', () {
      final String source = File(
        'lib/features/messaging/presentation/pages/staff_customer_messaging_page.dart',
      ).readAsStringSync();

      expect(source, contains('PopScope('));
      expect(source, contains('_refreshInboxOnce'));
      expect(source, contains('_refreshMessagesOnce'));
      expect(source, contains('RefreshIndicator('));
      expect(source, contains('AlwaysScrollableScrollPhysics'));
      expect(source, contains('Boîte clients · votre zone'));
    });
  });
}
