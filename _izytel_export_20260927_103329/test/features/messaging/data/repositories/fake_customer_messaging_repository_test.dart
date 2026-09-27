import 'package:cabine_flow/features/messaging/data/repositories/fake_customer_messaging_repository.dart';
import 'package:cabine_flow/features/messaging/domain/models/customer_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC3 - FakeCustomerMessagingRepository', () {
    late FakeCustomerMessagingRepository repository;

    setUp(() {
      repository = FakeCustomerMessagingRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('client crée une conversation liée à sa commande', () async {
      final CustomerConversation conversation = await repository
          .createConversation(
            orderId: 'order-12345678',
            orderReference: 'CF-20260926-ABC123',
            message: 'Je souhaite une vérification.',
          );

      expect(conversation.status, CustomerConversationStatus.open);
      expect(conversation.orderReference, 'CF-20260926-ABC123');

      final List<CustomerMessage> messages = await repository
          .watchMessages(conversationId: conversation.id)
          .first;
      expect(messages, hasLength(1));
      expect(messages.single.senderType, CustomerMessageSenderType.client);
    });

    test('Manager prend en charge puis répond sans exposer Agent', () async {
      final CustomerConversation conversation = await repository
          .createConversation(message: 'Bonjour IzyTel');

      await repository.takeConversation(conversationId: conversation.id);
      await repository.sendManagerMessage(
        conversationId: conversation.id,
        message: 'Bonjour, je prends votre demande en charge.',
      );

      final List<CustomerConversation> inbox = await repository
          .watchManagerInbox()
          .first;
      final CustomerConversation updated = inbox.single;
      expect(updated.status, CustomerConversationStatus.inProgress);
      expect(updated.assignedManagerUid, 'manager-test-uid');
      expect(updated.lastSenderType, CustomerMessageSenderType.manager);

      final List<CustomerMessage> messages = await repository
          .watchMessages(conversationId: conversation.id)
          .first;
      expect(
        messages.map((CustomerMessage item) => item.senderType),
        containsAll(<CustomerMessageSenderType>[
          CustomerMessageSenderType.client,
          CustomerMessageSenderType.system,
          CustomerMessageSenderType.manager,
        ]),
      );
    });

    test('une réponse client rouvre une conversation résolue', () async {
      final CustomerConversation conversation = await repository
          .createConversation(message: 'Besoin d’aide');
      await repository.takeConversation(conversationId: conversation.id);
      await repository.resolveConversation(conversationId: conversation.id);

      CustomerConversation resolved = (await repository
          .watchCustomerConversations()
          .first).single;
      expect(resolved.status, CustomerConversationStatus.resolved);

      await repository.sendClientMessage(
        conversationId: conversation.id,
        message: 'Le problème persiste.',
      );

      resolved = (await repository.watchCustomerConversations().first).single;
      expect(resolved.status, CustomerConversationStatus.inProgress);
      expect(resolved.lastSenderType, CustomerMessageSenderType.client);
    });
  });
}
