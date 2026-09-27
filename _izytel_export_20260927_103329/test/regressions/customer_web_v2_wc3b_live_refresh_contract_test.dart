import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('WC3B live - un envoi client est relu immediatement depuis Supabase', () {
    final String page = source(
      'lib/features/messaging/presentation/pages/customer_messaging_page.dart',
    );

    expect(page, contains('sendClientMessage('));
    expect(page, contains('.watchMessages(conversationId: conversation.id)'));
    expect(page, contains('.first;'));
    expect(page, contains('_messages = refreshedMessages'));
  });

  test('WC3B live - Realtime a un fallback REST borne', () {
    final String repository = source(
      'lib/features/messaging/data/repositories/supabase_customer_messaging_repository.dart',
    );

    expect(repository, contains('CustomerMessaging.messages-fallback'));
    expect(repository, contains('Duration(seconds: 2)'));
    expect(repository, contains('yield await _fetchMessages(id)'));
    expect(repository, contains('CustomerMessaging.conversations-fallback'));
    expect(repository, contains('Duration(seconds: 5)'));
    expect(
      repository,
      contains('yield await _fetchConversations(customerUid: customerUid)'),
    );
  });

  test('WC3B live - la messagerie reste Supabase et ne cree aucun flux Firestore', () {
    final String repository = source(
      'lib/features/messaging/data/repositories/supabase_customer_messaging_repository.dart',
    );

    expect(repository, contains("'izytel_wc3_send_client_message'"));
    expect(repository, isNot(contains('FirebaseFirestore')));
    expect(repository, isNot(contains('firestore.rules')));
  });
}
