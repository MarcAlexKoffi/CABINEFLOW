import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Web Client V2 - WC3B interface messagerie Client', () {
    late String flow;
    late String help;
    late String home;
    late String messagingPage;

    setUpAll(() {
      flow = File(
        'lib/features/customer_order/presentation/pages/customer_order_flow_page.dart',
      ).readAsStringSync();
      help = File(
        'lib/features/support/presentation/pages/customer_help_page.dart',
      ).readAsStringSync();
      home = File(
        'lib/features/customer_order/presentation/pages/customer_home_page.dart',
      ).readAsStringSync();
      messagingPage = File(
        'lib/features/messaging/presentation/pages/customer_messaging_page.dart',
      ).readAsStringSync();
    });

    test('Aide ouvre une vraie surface Messagerie IzyTel', () {
      expect(flow, contains('_CustomerSurface.messaging'));
      expect(flow, contains('createOperationalCustomerMessagingRepository'));
      expect(flow, contains('CustomerMessagingPage('));
      expect(flow, contains('orders: _viewModel.customerOrders'));
      expect(help, contains("title: 'Messagerie IzyTel'"));
      expect(help, contains('onTap: onOpenMessaging'));
    });

    test('WhatsApp devient un canal externe complementaire', () {
      expect(help, contains("title: 'WhatsApp (support externe)'"));
      expect(help, contains('Canal complémentaire'));
      expect(
        home,
        contains('Écrivez d’abord dans la messagerie IzyTel'),
      );
      expect(
        help,
        contains('référence et son code de récupération'),
      );
    });

    test('le Client peut creer lire et repondre sans action Staff', () {
      expect(messagingPage, contains('watchCustomerConversations()'));
      expect(messagingPage, contains('.watchMessages('));
      expect(messagingPage, contains('.createConversation('));
      expect(messagingPage, contains('.sendClientMessage('));
      expect(messagingPage, isNot(contains('.takeConversation(')));
      expect(messagingPage, isNot(contains('.sendManagerMessage(')));
      expect(messagingPage, isNot(contains('.resolveConversation(')));
    });

    test('une conversation peut etre liee a une commande legitime', () {
      expect(messagingPage, contains('orderId: order?.id'));
      expect(messagingPage, contains('orderReference: order?.reference'));
      expect(messagingPage, contains('Commande concernée'));
      expect(messagingPage, contains(r'Commande ${conversation.orderReference}'));
    });

    test('Client Manager et Systeme sont visuellement distingues', () {
      expect(messagingPage, contains("return 'Vous';"));
      expect(messagingPage, contains("return 'Manager IzyTel';"));
      expect(messagingPage, contains("return 'IzyTel';"));
      expect(messagingPage, contains('message.isSystem'));
      expect(messagingPage, contains('CustomerMessageSenderType.system'));
      expect(
        messagingPage,
        contains('L’Agent qui exécute une commande n’échange pas directement avec le client.'),
      );
    });

    test('la messagerie reste responsive et conserve la navigation Client', () {
      expect(messagingPage, contains('constraints.maxWidth >= 900'));
      expect(messagingPage, contains('IzyTelBottomNavigation('));
      expect(
        messagingPage,
        contains('current: IzyTelCustomerDestination.help'),
      );
    });
  });
}
