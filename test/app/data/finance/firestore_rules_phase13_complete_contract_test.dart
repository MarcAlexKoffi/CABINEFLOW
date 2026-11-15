import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  test('13B protège fournisseurs, recharges et règlements', () {
    expect(rules, contains('match /financeSuppliers/{supplierId}'));
    expect(rules, contains('match /supplierRecharges/{rechargeId}'));
    expect(rules, contains('match /supplierAccounts/{accountId}'));
    expect(rules, contains('match /supplierPayments/{paymentId}'));
    expect(rules, contains('isValidSupplierRechargeCreation'));
    expect(rules, contains('isValidSupplierPaymentCreation'));
    expect(rules, contains("transactionId == 'recharge_' + rechargeId"));
    expect(rules, contains("request.resource.data.type == 'supplierRecharge'"));
    expect(
      rules,
      contains(
        'request.resource.data.amountOwed == request.resource.data.principalAmount',
      ),
    );
    expect(
      rules,
      contains('request.resource.data.network in agent.authorizedNetworks'),
    );
  });

  test(
    '13D impose un règlement atomique et interdit le surpaiement client',
    () {
      expect(rules, contains('match /customerCredits/{creditId}'));
      expect(
        rules,
        contains('match /customerCreditSettlements/{settlementId}'),
      );
      expect(rules, contains('isValidCustomerCreditCreation'));
      expect(rules, contains('isValidCustomerCreditSettlementCreation'));
      expect(rules, contains('isValidAdminCreditAuthorization'));
      expect(rules, contains('paymentStatusAllowsProcessing'));
      expect(rules, contains("'CREDIT_AUTHORIZED'"));
      expect(
        rules,
        contains("request.resource.data.paymentStatus == 'credit'"),
      );
      expect(
        rules,
        contains(
          'request.resource.data.amount <= credit.amount - credit.paidAmount',
        ),
      );
      expect(rules, contains('request.resource.data.paidAmount == nextPaid'));
    },
  );

  test('13E et 13G gardent dépenses et clôtures immuables', () {
    expect(rules, contains('match /financeExpenses/{expenseId}'));
    expect(rules, contains('hasValidFinanceExpenseValues'));
    expect(rules, contains("request.resource.data.paymentChannel == 'wave'"));
    expect(
      rules,
      contains("request.resource.data.get('paymentReference', '').size() >= 3"),
    );
    expect(rules, contains('match /dailyFinancialClosings/{closingId}'));
    expect(rules, contains('hasValidDailyClosingValues'));
    expect(
      rules,
      contains(
        'request.resource.data.waveDifference\n          == request.resource.data.waveActualBalance - request.resource.data.waveTheoreticalBalance',
      ),
    );
    expect(
      rules,
      contains(
        "request.resource.data.get('waveDifferenceNote', '').size() >= 3",
      ),
    );
  });

  test('13C réserve le paramètre de caisse Wave aux administrateurs', () {
    expect(rules, contains('match /financeSettings/{settingId}'));
    expect(rules, contains('match /waveBalanceAdjustments/{adjustmentId}'));
    expect(rules, contains('hasValidWaveBalanceAdjustmentValues'));
    expect(rules, contains('lastAdjustmentId'));
    expect(rules, contains("settingId == 'wave'"));
    expect(
      rules,
      contains('request.resource.data.effectiveAt == request.time'),
    );
    expect(rules, contains('allow list: if false;'));
  });

  test(
    'journaux financiers sensibles ne sont pas modifiables après création',
    () {
      for (final String matchName in <String>[
        'supplierRecharges',
        'supplierPayments',
        'customerCreditSettlements',
        'financeExpenses',
        'waveBalanceAdjustments',
        'dailyFinancialClosings',
        'networkTransactions',
      ]) {
        final int start = rules.indexOf('match /$matchName/');
        expect(start, greaterThanOrEqualTo(0), reason: matchName);
        final int next = rules.indexOf('\n    match /', start + 1);
        final String block = rules.substring(
          start,
          next < 0 ? rules.length : next,
        );
        expect(
          block,
          contains('allow update, delete: if false;'),
          reason: matchName,
        );
      }
    },
  );
}
