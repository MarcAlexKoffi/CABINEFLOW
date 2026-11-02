import 'package:cabine_flow/backoffice/data/repositories/supabase_backoffice_finance_repository.dart';
import 'package:cabine_flow/backoffice/domain/repositories/backoffice_finance_repository.dart';
import 'package:cabine_flow/features/commissions/data/repositories/firestore_commission_repository.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/agent_commission_summary_repository.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_phase5_finance_repository.dart';

/// Phase 5 : commissions et versements sont lus depuis Supabase.
///
/// Firestore ne subsiste ici que pour les métriques opérationnelles non encore
/// migrées et pour le miroir transactionnel temporaire d'un nouveau versement.
class HybridCommissionRepository
    implements CommissionRepository, AgentCommissionSummaryRepository {
  HybridCommissionRepository({
    FirestoreCommissionRepository? firestoreRepository,
    SupabasePhase5FinanceRepository? phase5Repository,
    BackofficeFinanceRepository? payoutRepository,
  }) : _firestore = firestoreRepository ?? FirestoreCommissionRepository(),
       _phase5 = phase5Repository ?? SupabasePhase5FinanceRepository(),
       _payouts = payoutRepository;

  final FirestoreCommissionRepository _firestore;
  final SupabasePhase5FinanceRepository _phase5;
  final BackofficeFinanceRepository? _payouts;

  @override
  Stream<AgentCommissionSummary> watchAgentCommissionSummary() =>
      _phase5.watchAgentCommissionSummary();

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
      _firestore.watchAssignmentMetrics(agentId: agentId);

  @override
  Stream<List<AgentProcessingMetric>> watchProcessingMetrics({String? agentId}) =>
      _firestore.watchProcessingMetrics(agentId: agentId);

  @override
  Stream<List<AgentOrderMetric>> watchOrderMetrics({String? agentId}) =>
      _firestore.watchOrderMetrics(agentId: agentId);

  @override
  Future<void> recordPayout({
    required String agentId,
    required String agentName,
    required int amount,
    required String paymentReference,
    required String staffId,
    required String staffName,
    String? note,
  }) async {
    await (_payouts ?? SupabaseBackofficeFinanceRepository()).recordCommissionPayout(
      agentId: agentId,
      agentName: agentName,
      amount: amount,
      reference: paymentReference,
      staffName: staffName,
      note: note,
    );
  }
}
