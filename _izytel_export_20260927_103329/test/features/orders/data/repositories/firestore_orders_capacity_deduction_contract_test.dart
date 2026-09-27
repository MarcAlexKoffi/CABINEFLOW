import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la réussite Agent déduit atomiquement la capacité du réseau', () {
    final String source = File(
      'lib/features/orders/data/repositories/firestore_orders_repository.dart',
    ).readAsStringSync();

    expect(source, contains('AgentCapacityPolicy.remainingAfterSuccess'));
    expect(source, contains('_agentCapacityFieldForNetwork(order.network)'));
    expect(source, contains('transaction.update(profileRef'));
    expect(
      source,
      contains("'lastCapacityUpdateAt': FieldValue.serverTimestamp()"),
    );
    expect(source, contains('[AgentCapacity][deduct]'));
  });
}
