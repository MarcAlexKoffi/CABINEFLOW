import 'package:cabine_flow/features/commissions/domain/models/commission_v2_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommissionAccountV2', () {
    test('calcule les états de règlement sans toucher aux commissions', () {
      expect(
        _account(earned: 0, paid: 0).settlementState,
        CommissionSettlementState.empty,
      );
      expect(
        _account(earned: 100, paid: 0).settlementState,
        CommissionSettlementState.unpaid,
      );
      expect(
        _account(earned: 100, paid: 60).settlementState,
        CommissionSettlementState.partial,
      );
      expect(
        _account(earned: 100, paid: 100).settlementState,
        CommissionSettlementState.paid,
      );
      expect(_account(earned: 100, paid: 60).outstanding, 40);
    });
  });

  group('CommissionV2Snapshot.apply', () {
    final DateTime now = DateTime(2026, 9, 10, 18);
    late CommissionV2Snapshot snapshot;

    setUp(() {
      snapshot = CommissionV2Snapshot(
        commissions: <CommissionV2Entry>[
          _commission(
            id: 'order-a',
            agentId: 'agent-a',
            agentName: 'Agent Alpha',
            network: 'orange',
            amount: 10,
            earnedAt: DateTime(2026, 9, 10, 10),
          ),
          _commission(
            id: 'order-b',
            agentId: 'agent-a',
            agentName: 'Agent Alpha',
            network: 'mtn',
            amount: 10,
            earnedAt: DateTime(2026, 9, 5, 9),
          ),
          _commission(
            id: 'order-c',
            agentId: 'agent-b',
            agentName: 'Agent Beta',
            network: 'moov',
            amount: 10,
            earnedAt: DateTime(2026, 8, 30, 9),
          ),
        ],
        payouts: <CommissionPayoutV2Entry>[
          _payout(
            id: 'payout-a',
            agentId: 'agent-a',
            agentName: 'Agent Alpha',
            amount: 15,
            reference: 'WAVE-ALPHA',
            paidAt: DateTime(2026, 9, 7, 14),
          ),
          _payout(
            id: 'payout-b',
            agentId: 'agent-b',
            agentName: 'Agent Beta',
            amount: 10,
            reference: 'WAVE-BETA',
            paidAt: DateTime(2026, 8, 31, 14),
          ),
        ],
        accounts: <CommissionAccountV2>[
          const CommissionAccountV2(
            agentId: 'agent-a',
            agentName: 'Agent Alpha',
            earnedTotal: 20,
            paidTotal: 15,
            earnedTransactions: 2,
          ),
          const CommissionAccountV2(
            agentId: 'agent-b',
            agentName: 'Agent Beta',
            earnedTotal: 10,
            paidTotal: 10,
            earnedTransactions: 1,
          ),
        ],
      );
    });

    test('filtre ce mois et produit les statistiques exactes', () {
      final CommissionV2View view = snapshot.apply(
        const CommissionV2Filter(period: CommissionV2Period.thisMonth),
        now: now,
      );

      expect(view.commissions.length, 2);
      expect(view.payouts.length, 1);
      expect(view.stats.generatedAmount, 20);
      expect(view.stats.paidAmount, 15);
      expect(view.stats.currentOutstanding, 5);
      expect(view.timeline.length, 3);
      expect(view.timeline.first.date, DateTime(2026, 9, 10, 10));
    });

    test('un filtre réseau ne fabrique aucun versement réseau', () {
      final CommissionV2View view = snapshot.apply(
        const CommissionV2Filter(
          period: CommissionV2Period.all,
          network: 'orange',
        ),
        now: now,
      );

      expect(view.commissions.length, 1);
      expect(view.commissions.single.network, 'orange');
      expect(view.timeline.every((item) => item.network == 'orange'), isTrue);
      expect(view.stats.generatedAmount, 10);
      expect(view.stats.paidAmount, isNull);
      expect(view.stats.currentOutstanding, isNull);
    });

    test('le filtre Partiel limite comptes et historique aux Agents concernés', () {
      final CommissionV2View view = snapshot.apply(
        const CommissionV2Filter(
          period: CommissionV2Period.all,
          settlementState: CommissionSettlementState.partial,
        ),
        now: now,
      );

      expect(view.accounts.length, 1);
      expect(view.accounts.single.agentId, 'agent-a');
      expect(view.commissions.every((item) => item.agentId == 'agent-a'), isTrue);
      expect(view.payouts.every((item) => item.agentId == 'agent-a'), isTrue);
    });

    test('la recherche retrouve référence commande ou référence Wave', () {
      final CommissionV2View orderView = snapshot.apply(
        const CommissionV2Filter(
          period: CommissionV2Period.all,
          query: 'REF-order-b',
        ),
        now: now,
      );
      expect(
        orderView.commissions.map((item) => item.id).toList(),
        <String>['order-b'],
      );
      expect(orderView.accounts.map((item) => item.agentId).toList(), <String>['agent-a']);

      final CommissionV2View payoutView = snapshot.apply(
        const CommissionV2Filter(
          period: CommissionV2Period.all,
          query: 'wave-alpha',
        ),
        now: now,
      );
      expect(
        payoutView.payouts.map((item) => item.id).toList(),
        <String>['payout-a'],
      );
      expect(payoutView.accounts.map((item) => item.agentId).toList(), <String>['agent-a']);
    });
  });
}

CommissionAccountV2 _account({required int earned, required int paid}) {
  return CommissionAccountV2(
    agentId: 'agent',
    agentName: 'Agent',
    earnedTotal: earned,
    paidTotal: paid,
    earnedTransactions: earned ~/ 10,
  );
}

CommissionV2Entry _commission({
  required String id,
  required String agentId,
  required String agentName,
  required String network,
  required int amount,
  required DateTime earnedAt,
}) {
  return CommissionV2Entry(
    id: id,
    orderId: id,
    orderReference: 'REF-$id',
    agentId: agentId,
    agentName: agentName,
    network: network,
    orderAmount: 1000,
    commissionAmount: amount,
    policyId: 'fixed-10-v1',
    policyType: 'fixedPerSuccessfulTransaction',
    rate: 10,
    earnedAt: earnedAt,
  );
}

CommissionPayoutV2Entry _payout({
  required String id,
  required String agentId,
  required String agentName,
  required int amount,
  required String reference,
  required DateTime paidAt,
}) {
  return CommissionPayoutV2Entry(
    id: id,
    agentId: agentId,
    agentName: agentName,
    amount: amount,
    paymentChannel: 'wave',
    paymentReference: reference,
    paidAt: paidAt,
  );
}
