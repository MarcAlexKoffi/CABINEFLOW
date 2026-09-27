import 'package:cabine_flow/backoffice/domain/models/backoffice_finance_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({
  Map<String, dynamic>? waveOpening,
  List<Map<String, dynamic>> credits = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> settlements = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> expenses = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> suppliers = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> supplierAccounts = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> supplierRecharges = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> supplierPayments = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> commissionAccounts = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> commissions = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> commissionPayouts = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> capacities = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> movements = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> orderPayments = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> refunds = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> orders = const <Map<String, dynamic>>[],
}) {
  return <String, dynamic>{
    'generated_at': '2026-09-15T12:00:00Z',
    'wave_opening': waveOpening,
    'wave_adjustments': <Map<String, dynamic>>[],
    'credits': credits,
    'credit_settlements': settlements,
    'expenses': expenses,
    'closings': <Map<String, dynamic>>[],
    'suppliers': suppliers,
    'supplier_accounts': supplierAccounts,
    'supplier_recharges': supplierRecharges,
    'supplier_payments': supplierPayments,
    'commission_accounts': commissionAccounts,
    'commissions': commissions,
    'commission_payouts': commissionPayouts,
    'agent_capacities': capacities,
    'network_movements': movements,
    'order_payments': orderPayments,
    'refunds': refunds,
    'orders': orders,
    'success_finalizations': <Map<String, dynamic>>[],
    'ledger_events': <Map<String, dynamic>>[],
    'audit_events': <Map<String, dynamic>>[],
  };
}

void main() {
  group('BO-5 - calculs financiers', () {
    test('Wave ignore les flux anterieurs au dernier solde d ouverture', () {
      final BackofficeFinanceSnapshot snapshot = BackofficeFinanceSnapshot.fromJson(
        _json(
          waveOpening: <String, dynamic>{
            'opening_balance': 10000,
            'effective_at': '2026-09-15T08:00:00Z',
          },
          orders: <Map<String, dynamic>>[
            <String, dynamic>{
              'order_id': 'before',
              'amount': 500,
              'payment_status': 'confirmed',
              'payment_confirmed_at': '2026-09-15T07:00:00Z',
            },
            <String, dynamic>{
              'order_id': 'after',
              'amount': 1000,
              'payment_status': 'confirmed',
              'payment_confirmed_at': '2026-09-15T09:00:00Z',
            },
          ],
          settlements: <Map<String, dynamic>>[
            <String, dynamic>{
              'amount': 500,
              'payment_channel': 'wave',
              'paid_at': '2026-09-15T10:00:00Z',
            },
          ],
          supplierPayments: <Map<String, dynamic>>[
            <String, dynamic>{
              'amount': 300,
              'payment_channel': 'wave',
              'paid_at': '2026-09-15T10:10:00Z',
            },
          ],
          expenses: <Map<String, dynamic>>[
            <String, dynamic>{
              'amount': 100,
              'payment_channel': 'wave',
              'spent_at': '2026-09-15T10:20:00Z',
            },
          ],
          refunds: <Map<String, dynamic>>[
            <String, dynamic>{
              'amount': 200,
              'payment_channel': 'wave',
              'refunded_at': '2026-09-15T10:30:00Z',
            },
          ],
          commissionPayouts: <Map<String, dynamic>>[
            <String, dynamic>{
              'amount': 50,
              'payment_channel': 'wave',
              'paid_at': '2026-09-15T10:40:00Z',
            },
          ],
        ),
      );

      expect(snapshot.waveIncomingSinceOpening, 1500);
      expect(snapshot.waveOutgoingSinceOpening, 650);
      expect(snapshot.waveTheoreticalBalance, 10850);
      expect(
        snapshot.confirmedReceiptsOn(DateTime(2026, 9, 15)),
        1500,
        reason: 'la cloture du jour reste distincte du point d ouverture Wave',
      );
    });

    test('le ledger paiement duplique ne double pas les encaissements clients', () {
      final BackofficeFinanceSnapshot snapshot = BackofficeFinanceSnapshot.fromJson(
        _json(
          orders: <Map<String, dynamic>>[
            <String, dynamic>{
              'order_id': 'order-1',
              'amount': 1000,
              'payment_status': 'confirmed',
              'payment_confirmed_at': '2026-09-15T09:00:00Z',
            },
          ],
          orderPayments: <Map<String, dynamic>>[
            <String, dynamic>{'order_id': 'order-1', 'amount': 1000},
            <String, dynamic>{'order_id': 'order-1', 'amount': 1000},
          ],
        ),
      );

      expect(snapshot.confirmedReceiptsOn(DateTime(2026, 9, 15)), 1000);
    });

    test('le fonds de roulement retire la capacite deja engagee', () {
      final BackofficeFinanceSnapshot snapshot = BackofficeFinanceSnapshot.fromJson(
        _json(
          waveOpening: <String, dynamic>{
            'opening_balance': 10850,
            'effective_at': '2026-09-15T12:00:00Z',
          },
          capacities: <Map<String, dynamic>>[
            <String, dynamic>{
              'orange_capacity': 10000,
              'mtn_capacity': 5000,
              'moov_capacity': 2000,
            },
          ],
          orders: <Map<String, dynamic>>[
            <String, dynamic>{
              'network': 'orange',
              'amount': 3000,
              'payment_status': 'confirmed',
              'order_status': 'paidReady',
              'assigned_agent_id': 'a1',
            },
            <String, dynamic>{
              'network': 'mtn',
              'amount': 1000,
              'payment_status': 'credit',
              'order_status': 'inProgress',
              'assigned_agent_id': 'a2',
            },
            <String, dynamic>{
              'network': 'orange',
              'amount': 999,
              'payment_status': 'confirmed',
              'order_status': 'completed',
              'assigned_agent_id': 'a1',
            },
          ],
          credits: <Map<String, dynamic>>[
            <String, dynamic>{'amount': 2000, 'paid_amount': 500},
          ],
          supplierAccounts: <Map<String, dynamic>>[
            <String, dynamic>{'total_owed': 5000, 'total_paid': 1000},
          ],
          commissionAccounts: <Map<String, dynamic>>[
            <String, dynamic>{'earned_total': 1000, 'paid_total': 300},
          ],
        ),
      );

      expect(snapshot.totalCommittedCapacity, 4000);
      expect(snapshot.totalFreeCapacity, 13000);
      expect(snapshot.operatingLiquidity, 23850);
      expect(snapshot.netWorkingCapital, 20650);
    });

    test('le resultat indicatif utilise le cout moyen reel des recharges', () {
      final BackofficeFinanceSnapshot snapshot = BackofficeFinanceSnapshot.fromJson(
        _json(
          supplierRecharges: <Map<String, dynamic>>[
            <String, dynamic>{
              'network': 'orange',
              'principal_amount': 10000,
              'received_amount': 10400,
            },
            <String, dynamic>{
              'network': 'mtn',
              'principal_amount': 10000,
              'received_amount': 10400,
            },
          ],
          movements: <Map<String, dynamic>>[
            <String, dynamic>{
              'network': 'orange',
              'direction': 'outgoing',
              'movement_type': 'orderSuccess',
              'amount': 1000,
              'order_id': 'success-1',
              'occurred_at': '2026-09-15T10:00:00Z',
            },
            <String, dynamic>{
              'network': 'mtn',
              'direction': 'outgoing',
              'movement_type': 'orderSuccess',
              'amount': 2000,
              'order_id': 'success-2',
              'occurred_at': '2026-09-15T10:30:00Z',
            },
          ],
          commissions: <Map<String, dynamic>>[
            <String, dynamic>{
              'commission_amount': 20,
              'earned_at': '2026-09-15T11:00:00Z',
            },
          ],
          expenses: <Map<String, dynamic>>[
            <String, dynamic>{
              'amount': 10,
              'payment_channel': 'cash',
              'spent_at': '2026-09-15T11:15:00Z',
            },
          ],
          refunds: <Map<String, dynamic>>[
            <String, dynamic>{
              'order_id': 'success-1',
              'amount': 100,
              'refunded_at': '2026-09-15T11:30:00Z',
            },
          ],
        ),
      );

      expect(snapshot.successfulOrdersAmountOn(DateTime(2026, 9, 15)), 3000);
      expect(snapshot.estimatedOperationalResultOn(DateTime(2026, 9, 15)), -15);
    });
  });
}
