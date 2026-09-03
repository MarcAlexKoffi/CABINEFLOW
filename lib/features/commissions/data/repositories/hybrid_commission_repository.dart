import 'package:cabine_flow/features/commissions/data/repositories/firestore_commission_repository.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/agent_commission_summary_repository.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_phase5_finance_repository.dart';
import 'package:flutter/foundation.dart';

/// Phase 5 : commissions et versements sont lus depuis Supabase.
///
/// Firestore ne subsiste ici que pour les métriques opérationnelles non encore
/// migrées et pour le miroir transactionnel temporaire d'un nouveau versement.
class HybridCommissionRepository
    implements CommissionRepository, AgentCommissionSummaryRepository {
  HybridCommissionRepository({
    FirestoreCommissionRepository? firestoreRepository,
    SupabasePhase5FinanceRepository? phase5Repository,
  }) : _firestore = firestoreRepository ?? FirestoreCommissionRepository(),
       _phase5 = phase5Repository ?? SupabasePhase5FinanceRepository();

  final FirestoreCommissionRepository _firestore;
  final SupabasePhase5FinanceRepository _phase5;

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
    // Pont transactionnel temporaire : les règles et écrans historiques
    // attendent encore le règlement dans Firebase. Supabase reste la source
    // de lecture et reçoit ensuite le miroir idempotent avec l'id legacy.
    await _firestore.recordPayout(
      agentId: agentId,
      agentName: agentName,
      amount: amount,
      paymentReference: paymentReference,
      staffId: staffId,
      staffName: staffName,
      note: note,
    );
    try {
      final List<CommissionPayout> values = await _firestore
          .watchPayouts(agentId: agentId)
          .first;
      CommissionPayout? created;
      for (final CommissionPayout item in values) {
        if (item.paymentReference.toUpperCase() ==
            paymentReference.trim().toUpperCase()) {
          created = item;
          break;
        }
      }
      if (created != null) await _phase5.mirrorCommissionPayout(created);
    } catch (error, stackTrace) {
      debugPrint('[Phase5][CommissionPayoutMirror] $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
