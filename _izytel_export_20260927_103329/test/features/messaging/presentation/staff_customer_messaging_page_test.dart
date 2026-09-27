import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/messaging/data/repositories/fake_customer_messaging_repository.dart';
import 'package:cabine_flow/features/messaging/presentation/pages/staff_customer_messaging_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const AppUser manager = AppUser(
    id: 'manager-test-uid',
    name: 'Manager Test',
    phoneNumber: '+2250102030405',
    role: UserRole.manager,
  );
  const AppUser admin = AppUser(
    id: 'admin-test-uid',
    name: 'Admin Test',
    phoneNumber: '+2250102030405',
    role: UserRole.administrator,
  );

  testWidgets('WC3C Manager prend en charge repond et resout', (
    WidgetTester tester,
  ) async {
    final FakeCustomerMessagingRepository repository =
        FakeCustomerMessagingRepository();
    final conversation = await repository.createConversation(
      orderId: 'order-test-0001',
      orderReference: 'CF-20260926-ABCD',
      message: 'Bonjour IzyTel',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StaffCustomerMessagingPage(
          user: manager,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Messagerie clients'), findsOneWidget);
    expect(find.text('Commande CF-20260926-ABCD'), findsOneWidget);

    await tester.tap(
      find.byKey(ValueKey<String>('wc3c-conversation-${conversation.id}')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('wc3c-take-conversation')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('wc3c-take-conversation')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('wc3c-manager-reply')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('wc3c-manager-reply')),
      'Bonjour, je prends votre demande en charge.',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('wc3c-send-manager-message')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Bonjour, je prends votre demande en charge.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('wc3c-resolve-conversation')),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Résolue'), findsWidgets);
    repository.dispose();
  });

  testWidgets('WC3C Admin supervise sans action Manager', (
    WidgetTester tester,
  ) async {
    final FakeCustomerMessagingRepository repository =
        FakeCustomerMessagingRepository();
    final conversation = await repository.createConversation(
      message: 'Je souhaite une assistance.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StaffCustomerMessagingPage(
          user: admin,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey<String>('wc3c-conversation-${conversation.id}')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Supervision en lecture seule'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('wc3c-take-conversation')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('wc3c-manager-reply')),
      findsNothing,
    );
    repository.dispose();
  });
}
