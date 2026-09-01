import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/features/finances/data/repositories/firestore_finance_operations_repository.dart',
    ).readAsStringSync();
  });

  test('utilise toutes les collections de la phase 13', () {
    for (final String collection in <String>[
      'financeSuppliers',
      'supplierAccounts',
      'supplierRecharges',
      'supplierPayments',
      'customerCredits',
      'customerCreditSettlements',
      'financeExpenses',
      'financeSettings',
      'waveBalanceAdjustments',
      'dailyFinancialClosings',
      'networkTransactions',
    ]) {
      expect(source, contains("collection('$collection')"), reason: collection);
    }
  });

  test(
    'recharge fournisseur écrit stock, dette et mouvement réseau dans une transaction',
    () {
      final int start = source.indexOf('Future<String> recordSupplierRecharge');
      final int end = source.indexOf(
        'Future<String> recordSupplierPayment',
        start,
      );
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final String block = source.substring(start, end);

      expect(block, contains('runTransaction'));
      expect(
        block,
        matches(
          RegExp(
            r"_networkTransactions\s*\.doc\(\s*'recharge_\$\{rechargeRef\.id\}'\s*\)",
          ),
        ),
      );
      expect(block, contains("'type': 'supplierRecharge'"));
      expect(block, contains("'direction': 'incoming'"));
      expect(block, contains('transaction.update(agentRef'));
      expect(block, contains('transaction.set(rechargeRef'));
      expect(block, contains('transaction.set(networkRef'));
      expect(block, contains('transaction.set(accountRef'));
    },
  );

  test(
    'crédit client finance atomiquement la commande sans simuler un paiement Wave',
    () {
      final int start = source.indexOf('Future<String> createCustomerCredit');
      final int end = source.indexOf(
        'Future<String> settleCustomerCredit',
        start,
      );
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final String block = source.substring(start, end);
      expect(
        block,
        matches(RegExp(r'_credits\s*\.doc\(\s*draft\.orderId\s*,?\s*\)')),
      );
      expect(block, contains('Un crédit existe déjà pour cette commande'));
      expect(
        block,
        contains("paymentStatus == 'confirmed' || paymentStatus == 'credit'"),
      );
      expect(block, contains("'paymentStatus': 'credit'"));
      expect(block, contains("'status': 'paidReady'"));
      expect(block, contains("'type': 'CREDIT_AUTHORIZED'"));
      expect(
        block,
        matches(
          RegExp(r'_autoAssignmentQueue\s*\.doc\(\s*draft\.orderId\s*,?\s*\)'),
        ),
      );
      expect(
        block,
        isNot(contains("'paymentConfirmedAt': FieldValue.serverTimestamp()")),
      );
      expect(block, isNot(contains("'paidAt': FieldValue.serverTimestamp()")));
    },
  );

  test(
    'recalage Wave est journalisé dans une transaction avec le nouveau point de départ',
    () {
      final int start = source.indexOf('Future<void> setWaveOpeningBalance');
      final int end = source.indexOf('Future<void> createDailyClosing', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final String block = source.substring(start, end);
      expect(block, contains('runTransaction'));
      expect(block, matches(RegExp(r'_waveAdjustments\s*\.doc\(\s*\)')));
      expect(block, contains("'previousOpeningBalance': previous"));
      expect(block, contains("'lastAdjustmentId': adjustmentRef.id"));
    },
  );

  test('clôture journalière est déterministe et refuse les doublons', () {
    final int start = source.indexOf('Future<void> createDailyClosing');
    expect(start, greaterThanOrEqualTo(0));
    final String block = source.substring(start);
    expect(
      block,
      matches(RegExp(r'_dailyClosings\s*\.doc\(\s*draft\.dateKey\s*,?\s*\)')),
    );
    expect(block, contains('Cette journée a déjà été clôturée'));
    expect(block, contains("'waveDifference': draft.waveDifference"));
    expect(
      block,
      contains("'waveDifferenceNote': _nullable(draft.waveDifferenceNote)"),
    );
  });
}
