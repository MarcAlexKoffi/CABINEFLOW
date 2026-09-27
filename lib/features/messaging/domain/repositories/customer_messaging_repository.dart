import 'package:cabine_flow/features/messaging/domain/models/customer_conversation.dart';

abstract interface class CustomerMessagingRepository {
  Stream<List<CustomerConversation>> watchCustomerConversations();

  Stream<List<CustomerConversation>> watchManagerInbox();

  Stream<List<CustomerMessage>> watchMessages({required String conversationId});

  Future<CustomerConversation> createConversation({
    String? orderId,
    String? orderReference,
    String? customerName,
    String? locationStatus,
    double? latitude,
    double? longitude,
    required String message,
  });

  Future<void> sendClientMessage({
    required String conversationId,
    required String message,
  });

  Future<void> takeConversation({required String conversationId});

  Future<void> sendManagerMessage({
    required String conversationId,
    required String message,
  });

  Future<void> resolveConversation({required String conversationId});
}
