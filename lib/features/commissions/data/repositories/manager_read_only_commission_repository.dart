import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_phase5_finance_repository.dart';

/// Commissions visibles par le Manager sans ouvrir les anciennes collections
/// Firestore Admin-only et sans autoriser de versement.
class ManagerReadOnlyCommissionRepository implements CommissionRepository {
  ManagerReadOnlyCommissionRepository({
    SupabasePhase5FinanceRepository? phase5Repository,
  }) : _phase5 = phase5Repository ?? SupabasePhase5FinanceRepository();

  final SupabasePhase5FinanceRepository _phase5;

  @override
  Stream<List<CommissionEntry>> watchCommissions({String? agentId}) =>
      _phase5.watchCommissions(agentId: agentId);

  @override
  Stream<List<CommissionPayout>> watchPayouts({String? agentId}) =>
      _phase5.watchCommissionPayouts(agentId: agentId);

  @override
  Stream<List<CommissionAccount>> watchAccounts({String? agentId}) =>
      _phase5.watchCommissionAccounts(agentId: agentId);

  @override
  Stream<List<AgentAssignmentMetric>> watchAssignmentMetrics({String? agentId}) =>
      Stream<List<AgentAssignmentMetric>>.value(
        const <AgentAssignmentMetric>[],
      );

  @override
  Stream<List<AgentProcessingMetric>> watchProcessingMetrics({String? agentId}) =>
      Stream<List<AgentProcessingMetric>>.value(
        const <AgentProcessingMetric>[],
      );

  @override
  Stream<List<AgentOrderMetric>> watchOrderMetrics({String? agentId}) =>
      Stream<List<AgentOrderMetric>>.value(const <AgentOrderMetric>[]);

  @override
  Future<void> recordPayout({
    required String agentId,
    required String agentName,
    required int amount,
    required String paymentReference,
    required String staffId,
    required String staffName,
    String? note,
  }) {
    throw StateError(
      'Le versement des commissions reste réservé à l’Administrateur.',
    );
  }
}
