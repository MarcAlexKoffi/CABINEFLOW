import 'package:cabine_flow/features/audit/domain/models/order_audit_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('affiche le nom réel puis le rôle de l acteur', () {
    final OrderAuditEntry entry = OrderAuditEntry(
      id: 'event-1',
      orderId: 'order-1',
      occurredAt: DateTime(2026, 8, 29, 12),
      title: 'Paiement confirmé',
      source: OrderAuditSource.orderEvent,
      actorRole: 'admin',
      actorId: 'admin-1',
      actorName: 'Marc',
    );

    expect(entry.actorDisplayName, 'Marc');
    expect(entry.actorRoleLabel, 'Administrateur');
    expect(entry.source.label, 'Commande');
  });

  test('reste explicite quand l auteur historique n était pas enregistré', () {
    final OrderAuditEntry entry = OrderAuditEntry(
      id: 'support-1',
      orderId: 'order-1',
      occurredAt: DateTime(2026, 8, 29, 12),
      title: 'Dossier fermé',
      source: OrderAuditSource.supportRequest,
      actorRole: 'unknown',
    );

    expect(entry.actorDisplayName, 'Auteur non enregistré');
    expect(entry.actorRoleLabel, 'Rôle non enregistré');
  });
}
