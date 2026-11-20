import 'package:cabine_flow/app/domain/entities/backoffice/backoffice_finance_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'daily KPIs and receivables use complete totals beyond display windows',
    () {
      final s = BackofficeFinanceSnapshot.fromJson({
        'generated_at': '2026-11-20T02:00:00Z',
        'global_totals': {'customer_receivables': 601, 'credits_count': 601},
        'day_totals': {
          'date_key': '2026-11-20',
          'client_receipts': 120100,
          'expenses': 16010,
          'expenses_wave': 6010,
          'successful_orders_count': 1201,
          'successful_orders_amount': 120100,
          'commissions_earned': 2500,
          'commissions_paid': 500,
          'commissions_paid_by_channel': {'wave': 300, 'cash': 200},
          'credit_settlements': 580,
          'credit_settlements_by_channel': {'wave': 80, 'cash': 500},
          'supplier_recharge_received': 104000,
          'estimated_profit': 1234,
        },
        'orders': [
          {
            'amount': 100,
            'payment_status': 'confirmed',
            'paid_at': '2026-11-20T01:00:00Z',
          },
        ],
        'credits': [
          {'amount': 2, 'paid_amount': 1},
        ],
        'expenses': [
          {'amount': 10, 'spent_at': '2026-11-20T01:00:00Z'},
        ],
        'agent_capacities': [
          {'orange_capacity': 5000000, 'is_active': false},
          {'orange_capacity': 100000, 'is_active': true},
        ],
      });
      expect(s.confirmedReceiptsOn(s.businessDay), 120100);
      expect(s.expensesOn(s.businessDay), 16010);
      expect(s.expensesOn(s.businessDay, channel: 'wave'), 6010);
      expect(s.successfulOrdersCountOn(s.businessDay), 1201);
      expect(s.successfulOrdersAmountOn(s.businessDay), 120100);
      expect(s.commissionEarnedOn(s.businessDay), 2500);
      expect(s.commissionPaidOn(s.businessDay, channel: 'cash'), 200);
      expect(s.creditSettlementsOn(s.businessDay, channel: 'wave'), 80);
      expect(s.supplierRechargeOn(s.businessDay, 'received_amount'), 104000);
      expect(s.estimatedOperationalResultOn(s.businessDay), 1234);
      expect(s.customerReceivables, 601);
      expect(s.globalTotal('credits_count', s.credits.length), 601);
      expect(s.capacityFor('orange'), 5100000);
      expect(s.inactiveCapacityFor('orange'), 5000000);
    },
  );

  test('today aggregates are never reused for a different day', () {
    final s = BackofficeFinanceSnapshot.fromJson({
      'day_totals': {'date_key': '2026-11-20', 'expenses': 999},
      'expenses': [
        {'amount': 10, 'spent_at': '2026-11-19T01:00:00Z'},
      ],
    });
    expect(s.expensesOn(DateTime(2026, 11, 19)), 10);
    expect(s.expensesOn(DateTime(2026, 11, 20)), 999);
  });
}
