import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'la réussite Agent crée atomiquement une seule commission et met à jour le compte',
    () {
      final String source = File(
        'lib/features/orders/data/repositories/firestore_orders_repository.dart',
      ).readAsStringSync();

      expect(source, contains("_firestore.collection('commissions')"));
      expect(source, contains("_firestore.collection('commissionAccounts')"));
      expect(source, contains('CommissionPolicy.current'));
      expect(source, contains('_commissionsCollection.doc(orderId)'));
      expect(
        source,
        contains(
          "'commissionAmount': commissionPolicy.amountPerSuccessfulTransaction",
        ),
      );
      expect(source, contains("'policyId': commissionPolicy.id"));
      expect(source, contains("'lastCommissionOrderId': order.id"));
      expect(source, contains('transaction.set(commissionRef'));
      expect(source, contains('transaction.update(commissionAccountRef'));
      expect(source, contains('transaction.set(commissionAccountRef'));
    },
  );

  test(
    'les paiements Wave utilisent une référence déterministe pour éviter les doublons accidentels',
    () {
      final String source = File(
        'lib/features/commissions/data/repositories/firestore_commission_repository.dart',
      ).readAsStringSync();

      expect(source, contains('_payoutDocumentId(cleanedReference)'));
      expect(source, contains('await transaction.get(payoutRef)'));
      expect(source, contains("Cette référence Wave a déjà été enregistrée."));
      expect(source, contains("paymentReference.trim().toUpperCase()"));
    },
  );

  test('refus et échec ne génèrent aucune écriture de commission', () {
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
    expect(successBlock, contains('transaction.set(commissionRef'));

    final String outsideSuccess =
        source.substring(0, successStart) + source.substring(failureStart);
    expect(outsideSuccess, isNot(contains('transaction.set(commissionRef')));
  });
}
