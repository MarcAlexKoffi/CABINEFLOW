import 'package:cabine_flow/features/audit/data/repositories/fake_order_audit_repository.dart';
import 'package:cabine_flow/features/audit/domain/models/order_audit_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'isole une commande et trie le journal du plus récent au plus ancien',
    () async {
      final FakeOrderAuditRepository repository = FakeOrderAuditRepository(
        entries: <OrderAuditEntry>[
          OrderAuditEntry(
            id: 'old',
            orderId: 'order-a',
            occurredAt: DateTime(2026, 8, 29, 10),
            title: 'Commande créée',
            source: OrderAuditSource.orderEvent,
            actorRole: 'customer',
          ),
          OrderAuditEntry(
            id: 'other',
            orderId: 'order-b',
            occurredAt: DateTime(2026, 8, 29, 13),
            title: 'Autre commande',
            source: OrderAuditSource.orderEvent,
            actorRole: 'customer',
          ),
          OrderAuditEntry(
            id: 'new',
            orderId: 'order-a',
            occurredAt: DateTime(2026, 8, 29, 12),
            title: 'Remboursement effectué',
            source: OrderAuditSource.refund,
            actorRole: 'admin',
          ),
        ],
      );
      addTearDown(repository.dispose);

      final List<OrderAuditEntry> entries = await repository
          .watchForOrder(orderId: 'order-a')
          .first;

      expect(entries.map((OrderAuditEntry value) => value.id), <String>[
        'new',
        'old',
      ]);
    },
  );

  test('réagit aux changements en temps réel', () async {
    final FakeOrderAuditRepository repository = FakeOrderAuditRepository();
    addTearDown(repository.dispose);

    final List<List<OrderAuditEntry>> emissions = <List<OrderAuditEntry>>[];
    final subscription = repository
        .watchForOrder(orderId: 'order-a')
        .listen(emissions.add);
    addTearDown(subscription.cancel);

    await Future<void>.delayed(Duration.zero);
    repository.replaceAll(<OrderAuditEntry>[
      OrderAuditEntry(
        id: 'event-1',
        orderId: 'order-a',
        occurredAt: DateTime(2026, 8, 29, 12),
        title: 'Paiement confirmé',
        source: OrderAuditSource.orderEvent,
        actorRole: 'admin',
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(emissions.first, isEmpty);
    expect(emissions.last.single.title, 'Paiement confirmé');
  });
}
