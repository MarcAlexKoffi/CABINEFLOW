import 'package:cabine_flow/features/messaging/data/repositories/fake_customer_messaging_repository.dart';
import 'package:cabine_flow/features/messaging/presentation/pages/customer_messaging_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('WC3B le client cree une conversation depuis la messagerie', (
    WidgetTester tester,
  ) async {
    final FakeCustomerMessagingRepository repository =
        FakeCustomerMessagingRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerMessagingPage(
          repository: repository,
          orders: const [],
          onBack: () {},
          onOpenHome: () {},
          onOpenOffers: () {},
          onOpenHistory: () {},
          onOpenHelp: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucune conversation'), findsOneWidget);
    await tester.tap(find.text('Écrire à IzyTel'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('wc3b-new-message-field')),
      'Bonjour IzyTel, je souhaite vérifier ma demande.',
    );
    final Finder createButton = find.byKey(
      const ValueKey<String>('wc3b-create-conversation'),
    );
    await tester.ensureVisible(createButton);
    await tester.pumpAndSettle();
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Bonjour IzyTel, je souhaite vérifier ma demande.'),
      findsOneWidget,
    );
    expect(find.text('Vous'), findsOneWidget);

    // IzyTelFeedback.success garde volontairement le toast 1,8 s.
    // On laisse ce timer se terminer avant de demonter l'arbre du test.
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    repository.dispose();
  });

  testWidgets('WC3B une reponse client reste dans le circuit IzyTel', (
    WidgetTester tester,
  ) async {
    final FakeCustomerMessagingRepository repository =
        FakeCustomerMessagingRepository();
    final conversation = await repository.createConversation(
      message: 'Premier message',
    );
    await repository.takeConversation(conversationId: conversation.id);
    await repository.sendManagerMessage(
      conversationId: conversation.id,
      message: 'Bonjour, votre demande est prise en charge.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerMessagingPage(
          repository: repository,
          orders: const [],
          onBack: () {},
          onOpenHome: () {},
          onOpenOffers: () {},
          onOpenHistory: () {},
          onOpenHelp: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Conversation IzyTel'));
    await tester.pumpAndSettle();

    expect(find.text('Manager IzyTel'), findsWidgets);
    expect(
      find.text('Bonjour, votre demande est prise en charge.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('wc3b-reply-field')),
      'Merci pour le retour.',
    );
    final Finder sendButton = find.byKey(
      const ValueKey<String>('wc3b-send-message'),
    );
    await tester.ensureVisible(sendButton);
    await tester.pumpAndSettle();
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    expect(find.text('Merci pour le retour.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    repository.dispose();
  });
}
