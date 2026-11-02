import 'package:cabine_flow/features/commissions/data/repositories/supabase_commission_v2_repository.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_phase5_finance_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Phase5 extends SupabasePhase5FinanceRepository {
  _Phase5()
    : super(client: SupabaseClient('http://localhost', 'synthetic-key'));
  final List<String?> requestedIds = [];
  @override
  Stream<List<CommissionEntry>> watchCommissions({String? agentId}) {
    requestedIds.add(agentId);
    return Stream.value([]);
  }

  @override
  Stream<List<CommissionPayout>> watchCommissionPayouts({String? agentId}) {
    requestedIds.add(agentId);
    return Stream.value([
      CommissionPayout(
        id: 'supabase-only',
        agentId: agentId ?? 'agent-a',
        agentName: 'Agent A',
        amount: 80,
        paymentChannel: 'wave',
        paymentReference: 'WAVE-1',
        paidAt: DateTime.utc(2026, 11, 1),
        createdBy: 'admin',
        createdByName: 'Admin',
      ),
    ]);
  }

  @override
  Stream<List<CommissionAccount>> watchCommissionAccounts({String? agentId}) {
    requestedIds.add(agentId);
    return Stream.value([
      CommissionAccount(
        agentId: agentId ?? 'agent-a',
        agentName: 'Agent A',
        earnedTotal: 100,
        paidTotal: 80,
        earnedTransactions: 10,
        updatedAt: DateTime.utc(2026, 11, 1),
      ),
    ]);
  }
}

void main() {
  test(
    'V2 shows canonical Supabase payout and account in Agent scope',
    () async {
      final source = _Phase5();
      final snapshot = await SupabaseCommissionV2Repository(
        repository: source,
      ).watchAgent(' agent-a ').first;
      expect(snapshot.payouts.single.id, 'supabase-only');
      expect(snapshot.accounts.single.outstanding, 20);
      expect(source.requestedIds, ['agent-a', 'agent-a', 'agent-a']);
    },
  );
  test(
    'Admin scope retains server-side authorization and all-agent query',
    () async {
      final source = _Phase5();
      await SupabaseCommissionV2Repository(
        repository: source,
      ).watchAdmin().first;
      expect(source.requestedIds, [null, null, null]);
    },
  );
  test('empty Agent id fails before opening a source', () async {
    final source = _Phase5();
    await expectLater(
      SupabaseCommissionV2Repository(repository: source).watchAgent(' '),
      emitsError(isArgumentError),
    );
    expect(source.requestedIds, isEmpty);
  });
}
