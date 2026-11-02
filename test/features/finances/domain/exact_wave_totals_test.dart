import 'package:cabine_flow/backoffice/domain/models/backoffice_finance_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a successful reserved Orange order reduces stock and releases its commitment',
    () {
      BackofficeFinanceSnapshot snapshot(int stock, int committed) =>
          BackofficeFinanceSnapshot.fromJson({
            'agent_capacities': [
              {'orange_capacity': stock},
            ],
            'committed_capacities': {'orange': committed},
          });
      final before = snapshot(165400, 59722);
      final after = snapshot(163900, 58222);

      expect(before.capacityFor('orange') - after.capacityFor('orange'), 1500);
      expect(
        before.committedFor('orange') - after.committedFor('orange'),
        1500,
      );
      expect(after.freeCapacityFor('orange'), 105678);
      expect(before.freeCapacityFor('orange'), after.freeCapacityFor('orange'));
    },
  );

  test(
    'server totals determine balance independently of truncated history',
    () {
      final snapshot = BackofficeFinanceSnapshot.fromJson({
        'wave_opening': {'opening_balance': 10000},
        'committed_capacities': {'orange': 120100},
        'orders': List.generate(
          1000,
          (_) => {
            'amount': 100,
            'payment_status': 'confirmed',
            'paid_at': '2026-11-01T09:00:00Z',
          },
        ),
        'expenses': List.generate(
          500,
          (_) => {
            'amount': 10,
            'payment_channel': 'wave',
            'spent_at': '2026-11-01T09:00:00Z',
          },
        ),
        'wave_totals': {
          'client_payments': 120100,
          'credit_settlements': 80,
          'supplier_payments': 90,
          'expenses': 6010,
          'refunds': 100,
          'commission_payouts': 110,
          'cabiniste_payouts': 250,
        },
      });
      expect(snapshot.waveTheoreticalBalance, 123620);
      expect(snapshot.waveIncomingSinceOpening, 120180);
      expect(snapshot.waveOutgoingSinceOpening, 6560);
      expect(snapshot.committedFor('orange'), 120100);
      expect(snapshot.committedFor('mtn'), 0);
    },
  );

  test('exact zero totals take precedence over nonempty detail arrays', () {
    final snapshot = BackofficeFinanceSnapshot.fromJson({
      'wave_totals': {'expenses': 0},
      'expenses': [
        {
          'amount': 400,
          'payment_channel': 'wave',
          'spent_at': '2026-11-01T09:00:00Z',
        },
      ],
    });
    expect(snapshot.waveExpensesSinceOpening, 0);
  });
}
