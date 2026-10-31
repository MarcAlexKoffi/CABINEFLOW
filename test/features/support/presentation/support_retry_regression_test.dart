import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/refunds/data/repositories/fake_refund_repository.dart';
import 'package:cabine_flow/features/support/data/repositories/fake_support_request_repository.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/presentation/pages/support_request_center_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Reessayer recree la lecture des demandes apres une erreur', (
    tester,
  ) async {
    final repository = _RetrySupport();
    await tester.pumpWidget(
      MaterialApp(
        home: SupportRequestCenterPage(
          user: const AppUser(
            id: 'manager-test',
            name: 'Manager',
            phoneNumber: '',
            role: UserRole.manager,
          ),
          repository: repository,
          refundRepository: FakeRefundRepository(),
          orderHistoryRepository: FakeOrdersRepository(isTest: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Impossible de charger les demandes clients.'),
      findsOneWidget,
    );
    expect(repository.calls, 1);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(
      find.text('Impossible de charger les demandes clients.'),
      findsNothing,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'test');
    await tester.pump();
    expect(repository.calls, 2, reason: 'search keeps the existing stream');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _RetrySupport extends FakeSupportRequestRepository {
  int calls = 0;
  @override
  Stream<List<SupportRequest>> watchAllRequests() {
    if (++calls == 1) return Stream.error(StateError('test failure'));
    return Stream.value(const []);
  }
}
