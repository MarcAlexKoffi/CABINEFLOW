import 'dart:async';

import 'package:cabine_flow/features/audit/domain/models/order_audit_entry.dart';
import 'package:cabine_flow/features/audit/domain/repositories/order_audit_repository.dart';

class FakeOrderAuditRepository implements OrderAuditRepository {
  FakeOrderAuditRepository({
    Iterable<OrderAuditEntry> entries = const <OrderAuditEntry>[],
  }) : _entries = List<OrderAuditEntry>.from(entries);

  final List<OrderAuditEntry> _entries;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<List<OrderAuditEntry>> watchForOrder({
    required String orderId,
  }) async* {
    yield _forOrder(orderId);
    yield* _changes.stream.map((_) => _forOrder(orderId));
  }

  void replaceAll(Iterable<OrderAuditEntry> entries) {
    _entries
      ..clear()
      ..addAll(entries);
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  List<OrderAuditEntry> _forOrder(String orderId) {
    final List<OrderAuditEntry> values = _entries
        .where((OrderAuditEntry entry) => entry.orderId == orderId)
        .toList(growable: false);
    values.sort(
      (OrderAuditEntry first, OrderAuditEntry second) =>
          second.occurredAt.compareTo(first.occurredAt),
    );
    return values;
  }

  Future<void> dispose() => _changes.close();
}
