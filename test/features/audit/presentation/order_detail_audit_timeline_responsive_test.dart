import 'package:cabine_flow/features/audit/data/repositories/fake_order_audit_repository.dart';
import 'package:cabine_flow/features/audit/domain/models/order_audit_entry.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/presentation/pages/order_detail_page.dart';
import 'package:cabine_flow/features/support/data/repositories/fake_support_request_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('le journal 11C reste exploitable sur 360 px', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final FakeOrdersRepository orders = FakeOrdersRepository(isTest: true);
    final QueueOrder order = (await orders.fetchOrderHistory()).first;
    final FakeSupportRequestRepository support = FakeSupportRequestRepository();
    final FakeOrderAuditRepository audit = FakeOrderAuditRepository(
      entries: <OrderAuditEntry>[
        OrderAuditEntry(
          id: 'refund-1',
          orderId: order.id,
          occurredAt: DateTime(2026, 8, 29, 14, 30),
          title:
              'Remboursement effectué avec une référence Wave volontairement longue',
          source: OrderAuditSource.refund,
          actorRole: 'admin',
          actorId: 'admin-identifier-very-long-for-responsive-test',
          actorName: 'Administrateur IzyTel',
          details: const <String>[
            'Montant : 15000 F CFA',
            'Référence Wave : WAVE-REF-20260829-1234567890',
          ],
          technicalType: 'REFUNDED',
        ),
        OrderAuditEntry(
          id: 'order-event-1',
          orderId: order.id,
          occurredAt: DateTime(2026, 8, 29, 13, 30),
          title: 'Paiement confirmé',
          source: OrderAuditSource.orderEvent,
          actorRole: 'admin',
          actorId: 'admin-1',
          actorName: 'Marc',
          technicalType: 'PAYMENT_CONFIRMED',
        ),
      ],
    );

    addTearDown(support.dispose);
    addTearDown(audit.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderDetailPage(
            user: const AppUser(
              id: 'admin-1',
              name: 'Marc',
              phoneNumber: '',
              role: UserRole.administrator,
            ),
            initialOrder: order,
            ordersRepository: orders,
            supportRequestRepository: support,
            auditRepository: audit,
            onBack: () {},
            onOpenCustomerHistory: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Journal d’activité'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Journal d’activité'), findsOneWidget);
    expect(find.textContaining('Remboursement effectué'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
