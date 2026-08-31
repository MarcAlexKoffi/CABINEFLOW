import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/features/finances/presentation/pages/finances_page.dart',
    ).readAsStringSync();
  });

  test('le tableau Finances écoute en temps réel les règlements de crédits', () {
    expect(
      source,
      contains('_financeOperationsRepository.watchCustomerCreditSettlements()'),
    );
    expect(source, contains('_creditSettlementsToday(creditSettlements)'));
    expect(
      source,
      contains('confirmedPaymentsToday + creditSettlementsToday'),
    );
  });

  test('la carte Wave ne compte que les crédits encaissés via Wave', () {
    expect(
      source,
      contains('channel: FinancePaymentChannel.wave'),
    );
    expect(
      source,
      contains('confirmedPaymentsToday + waveCreditSettlementsToday'),
    );
    expect(source, contains('waveToday: waveToday'));
  });

  test('le net Finances écoute aussi fournisseurs et dépenses', () {
    expect(
      source,
      contains('_financeOperationsRepository.watchSupplierPayments()'),
    );
    expect(source, contains('_financeOperationsRepository.watchExpenses()'));
    expect(source, contains('supplierPaymentsToday'));
    expect(source, contains('expensesToday'));
  });
}
