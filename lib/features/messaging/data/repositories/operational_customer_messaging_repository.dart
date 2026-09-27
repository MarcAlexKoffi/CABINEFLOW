import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/features/messaging/data/repositories/fake_customer_messaging_repository.dart';
import 'package:cabine_flow/features/messaging/data/repositories/supabase_customer_messaging_repository.dart';
import 'package:cabine_flow/features/messaging/domain/models/customer_conversation.dart';
import 'package:cabine_flow/features/messaging/domain/repositories/customer_messaging_repository.dart';
import 'package:firebase_core/firebase_core.dart';

CustomerMessagingRepository createOperationalCustomerMessagingRepository() {
  if (SupabaseBootstrap.isInitialized) {
    return SupabaseCustomerMessagingRepository();
  }
  if (Firebase.apps.isEmpty) {
    return FakeCustomerMessagingRepository();
  }
  return const _UnavailableCustomerMessagingRepository();
}

class _UnavailableCustomerMessagingRepository
    implements CustomerMessagingRepository {
  const _UnavailableCustomerMessagingRepository();

  StateError get _error => StateError(
    'Supabase est indisponible. La messagerie IzyTel ne bascule pas vers Firestore.',
  );

  @override
  Stream<List<CustomerConversation>> watchCustomerConversations() =>
      Stream<List<CustomerConversation>>.error(_error);

  @override
  Stream<List<CustomerConversation>> watchManagerInbox() =>
      Stream<List<CustomerConversation>>.error(_error);

  @override
  Stream<List<CustomerMessage>> watchMessages({required String conversationId}) =>
      Stream<List<CustomerMessage>>.error(_error);

  @override
  Future<CustomerConversation> createConversation({
    String? orderId,
    String? orderReference,
    String? customerName,
    String? locationStatus,
    double? latitude,
    double? longitude,
    required String message,
  }) => Future<CustomerConversation>.error(_error);

  @override
  Future<void> sendClientMessage({
    required String conversationId,
    required String message,
  }) => Future<void>.error(_error);

  @override
  Future<void> takeConversation({required String conversationId}) =>
      Future<void>.error(_error);

  @override
  Future<void> sendManagerMessage({
    required String conversationId,
    required String message,
  }) => Future<void>.error(_error);

  @override
  Future<void> resolveConversation({required String conversationId}) =>
      Future<void>.error(_error);
}
