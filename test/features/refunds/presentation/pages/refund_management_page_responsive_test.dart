import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/refunds/data/repositories/fake_refund_repository.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/presentation/pages/refund_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'la liste des remboursements tient sur un écran compact de 320 px',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final FakeRefundRepository repository = FakeRefundRepository();
      addTearDown(repository.dispose);
      await repository.create(
        request: const RefundCreationRequest(
          orderId: 'order-12345678',
          orderReference: 'CF-20260828-ABCDEFG',
          supportRequestId: 'support-12345678',
          supportRequestType: 'completedButNotReceived',
          supportRequestDescription:
              'Commande indiquée terminée mais le client ne voit toujours rien.',
          customerAuthUid: 'customer-1',
          clientName: 'Un nom de client assez long pour tester la responsivité',
          clientWhatsappPhone: '+2250102030405',
          originalAmount: 12500,
          amount: 12500,
          reason: RefundReason.serviceNotReceived,
          reasonNote: 'Vérification effectuée.',
          paymentChannel: 'wave',
          originalPaymentReference: 'WAVE-ORIGINAL-REFERENCE',
        ),
        staffId: 'admin-1',
        staffName: 'Marc Alex',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RefundManagementPage(
            user: const AppUser(
              id: 'admin-1',
              name: 'Marc Alex',
              phoneNumber: '+2250100000000',
              role: UserRole.administrator,
            ),
            repository: repository,
            orderHistoryRepository: _NoopHistoryRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Remboursements'), findsOneWidget);
      expect(find.textContaining('CF-20260828'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _NoopHistoryRepository implements OrderHistoryRepository {
  @override
  Future<List<QueueOrder>> fetchOrderHistory() async => <QueueOrder>[];

  @override
  Stream<List<QueueOrder>> watchOrderHistory() =>
      Stream<List<QueueOrder>>.value(<QueueOrder>[]);

  @override
  Future<QueueOrder> fetchOrderById({required String orderId}) {
    throw UnimplementedError();
  }
}
