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
      matches(
        RegExp(
          r'_financeOperationsRepository\s*\.watchCustomerCreditSettlements\s*\(\s*\)',
        ),
      ),
    );
    expect(
      source,
      matches(
        RegExp(r'_creditSettlementsToday\s*\(\s*creditSettlements\s*,?\s*\)'),
      ),
    );
    expect(
      source,
      matches(RegExp(r'confirmedPaymentsToday\s*\+\s*creditSettlementsToday')),
    );
  });

  test('la carte Wave ne compte que les crédits encaissés via Wave', () {
    expect(
      source,
      matches(RegExp(r'channel\s*:\s*FinancePaymentChannel\s*\.\s*wave')),
    );
    expect(
      source,
      matches(
        RegExp(r'confirmedPaymentsToday\s*\+\s*waveCreditSettlementsToday'),
      ),
    );
    expect(source, matches(RegExp(r'waveToday\s*:\s*waveToday')));
  });

  test('le net Finances écoute aussi fournisseurs et dépenses', () {
    expect(
      source,
      matches(
        RegExp(
          r'_financeOperationsRepository\s*\.watchSupplierPayments\s*\(\s*\)',
        ),
      ),
    );
    expect(
      source,
      matches(
        RegExp(r'_financeOperationsRepository\s*\.watchExpenses\s*\(\s*\)'),
      ),
    );
    expect(source, contains('supplierPaymentsToday'));
    expect(source, contains('expensesToday'));
  });
}
