import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'la réussite Agent crée atomiquement une sortie réseau déterministe',
    () {
      final String source = File(
        'lib/features/orders/data/repositories/firestore_orders_repository.dart',
      ).readAsStringSync();

      final int successStart = source.indexOf(
        'Future<QueueOrder> markAgentSuccessful',
      );
      final int failureStart = source.indexOf(
        'Future<QueueOrder> markAgentFailed',
      );
      expect(successStart, greaterThanOrEqualTo(0));
      expect(failureStart, greaterThan(successStart));

      final String successBlock = source.substring(successStart, failureStart);
      expect(source, contains("_firestore.collection('networkTransactions')"));
      expect(successBlock, contains(".doc('order_\$orderId')"));
      expect(successBlock, contains('transaction.set(networkTransactionRef'));
      expect(successBlock, contains("'direction': 'outgoing'"));
      expect(successBlock, contains("'type': 'orderSuccess'"));
      expect(successBlock, contains("'amount': order.amount"));
      expect(successBlock, contains("'capacityBefore': previousCapacity"));
      expect(successBlock, contains("'capacityAfter': remainingCapacity"));
      expect(successBlock, contains("'orderReference': order.reference"));
    },
  );

  test('un échec Agent ne crée aucune sortie réseau', () {
    final String source = File(
      'lib/features/orders/data/repositories/firestore_orders_repository.dart',
    ).readAsStringSync();
    final int successStart = source.indexOf(
      'Future<QueueOrder> markAgentSuccessful',
    );
    final int failureStart = source.indexOf(
      'Future<QueueOrder> markAgentFailed',
    );
    final String outsideSuccess =
        source.substring(0, successStart) + source.substring(failureStart);

    expect(
      outsideSuccess,
      isNot(contains('transaction.set(networkTransactionRef')),
    );
  });
}
