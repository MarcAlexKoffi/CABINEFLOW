import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  group('Web Client V2 - WC3C inbox Manager et supervision Admin', () {
    test('Manager dispose d un acces Messagerie clients dans Plus', () {
      final String more = read('lib/features/more/presentation/pages/more_page.dart');
      expect(more, contains("title: 'Messagerie clients'"));
      expect(more, contains('StaffCustomerMessagingPage'));
      expect(more, contains('createOperationalCustomerMessagingRepository'));
    });

    test('le circuit staff reste Manager uniquement pour les ecritures', () {
      final String page = read(
        'lib/features/messaging/presentation/pages/staff_customer_messaging_page.dart',
      );
      expect(page, contains('watchManagerInbox'));
      expect(page, contains('takeConversation'));
      expect(page, contains('sendManagerMessage'));
      expect(page, contains('resolveConversation'));
      expect(page, contains('Supervision en lecture seule'));
      expect(page, isNot(contains('Agent peut répondre')));
    });

    test('Back-office expose Messagerie clients dans la section Clients', () {
      final String shell = read(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      );
      expect(shell, contains('customerMessaging'));
      expect(shell, contains("return 'Messagerie clients';"));
      expect(shell, contains('_BackofficeSection.clients'));
      expect(shell, contains('StaffCustomerMessagingPage'));
      expect(shell, contains('embedded: true'));
    });

    test('WC3C ne cree aucune nouvelle dependance Firestore', () {
      final String page = read(
        'lib/features/messaging/presentation/pages/staff_customer_messaging_page.dart',
      );
      final String more = read('lib/features/more/presentation/pages/more_page.dart');
      expect(page, isNot(contains('cloud_firestore')));
      expect(more, isNot(contains('firestore.rules')));
    });
  });
}
