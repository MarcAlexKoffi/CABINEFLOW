import 'package:cabine_flow/features/messaging/domain/models/customer_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC3 - modèles de messagerie', () {
    test('les statuts exposent les libellés attendus', () {
      expect(CustomerConversationStatus.open.label, 'Nouvelle');
      expect(CustomerConversationStatus.inProgress.label, 'En cours');
      expect(CustomerConversationStatus.resolved.label, 'Résolue');
      expect(CustomerConversationStatus.closed.label, 'Fermée');
    });

    test('les valeurs Supabase inconnues restent sûres', () {
      expect(
        CustomerConversationStatusX.fromStorage('unexpected'),
        CustomerConversationStatus.open,
      );
      expect(
        CustomerMessageSenderTypeX.fromStorage('unexpected'),
        CustomerMessageSenderType.system,
      );
    });

    test('une conversation liée à une commande est identifiable', () {
      final DateTime now = DateTime(2026, 9, 26, 20);
      final CustomerConversation conversation = CustomerConversation(
        id: 'conversation-1',
        customerAuthUid: 'customer-12345678',
        orderId: 'order-12345678',
        orderReference: 'CF-20260926-ABC123',
        status: CustomerConversationStatus.open,
        lastMessageAt: now,
        lastMessagePreview: 'Bonjour',
        lastSenderType: CustomerMessageSenderType.client,
        createdAt: now,
        updatedAt: now,
      );

      expect(conversation.isOrderLinked, isTrue);
      expect(conversation.isAssigned, isFalse);
      expect(conversation.isResolved, isFalse);
      expect(conversation.isClosed, isFalse);
    });
  });
}
