import 'package:cabine_flow/features/commissions/data/repositories/fake_commission_repository.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un paiement réduit le solde sans supprimer les commissions', () async {
    final DateTime now = DateTime(2026, 8, 29);
    final FakeCommissionRepository repository = FakeCommissionRepository(
      accounts: <CommissionAccount>[
        CommissionAccount(
          agentId: 'agent-1',
          agentName: 'Marc Koffi',
          earnedTotal: 1000,
          paidTotal: 200,
          earnedTransactions: 100,
          updatedAt: now,
        ),
      ],
    );

    await repository.recordPayout(
      agentId: 'agent-1',
      agentName: 'Marc Koffi',
      amount: 500,
      paymentReference: 'WAVE-TEST-001',
      staffId: 'admin-1',
      staffName: 'Admin Test',
    );

    final List<CommissionAccount> accounts = await repository
        .watchAccounts(agentId: 'agent-1')
        .first;
    final List<CommissionPayout> payouts = await repository
        .watchPayouts(agentId: 'agent-1')
        .first;

    expect(accounts.single.paidTotal, 700);
    expect(accounts.single.balance, 300);
    expect(accounts.single.earnedTransactions, 100);
    expect(payouts.single.amount, 500);
    expect(payouts.single.paymentReference, 'WAVE-TEST-001');
  });

  test('un paiement supérieur au solde est refusé', () async {
    final FakeCommissionRepository repository = FakeCommissionRepository(
      accounts: <CommissionAccount>[
        CommissionAccount(
          agentId: 'agent-1',
          agentName: 'Marc Koffi',
          earnedTotal: 100,
          paidTotal: 80,
          earnedTransactions: 10,
          updatedAt: DateTime(2026, 8, 29),
        ),
      ],
    );

    await expectLater(
      repository.recordPayout(
        agentId: 'agent-1',
        agentName: 'Marc Koffi',
        amount: 30,
        paymentReference: 'WAVE-TEST-002',
        staffId: 'admin-1',
        staffName: 'Admin Test',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'une référence Wave déjà utilisée ne peut pas être enregistrée deux fois',
    () async {
      final DateTime now = DateTime(2026, 8, 29);
      final FakeCommissionRepository repository = FakeCommissionRepository(
        payouts: <CommissionPayout>[
          CommissionPayout(
            id: 'payout-1',
            agentId: 'agent-1',
            agentName: 'Marc Koffi',
            amount: 100,
            paymentChannel: 'wave',
            paymentReference: 'WAVE-UNIQUE-001',
            paidAt: now,
            createdBy: 'admin-1',
            createdByName: 'Admin Test',
          ),
        ],
        accounts: <CommissionAccount>[
          CommissionAccount(
            agentId: 'agent-1',
            agentName: 'Marc Koffi',
            earnedTotal: 1000,
            paidTotal: 100,
            earnedTransactions: 100,
            updatedAt: now,
          ),
        ],
      );

      await expectLater(
        repository.recordPayout(
          agentId: 'agent-1',
          agentName: 'Marc Koffi',
          amount: 100,
          paymentReference: 'wave-unique-001',
          staffId: 'admin-1',
          staffName: 'Admin Test',
        ),
        throwsA(isA<StateError>()),
      );
    },
  );
}
