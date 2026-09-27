import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';

abstract class CommissionRepository {
  Stream<List<CommissionEntry>> watchCommissions({String? agentId});

  Stream<List<CommissionPayout>> watchPayouts({String? agentId});

  Stream<List<CommissionAccount>> watchAccounts({String? agentId});

  Stream<List<AgentAssignmentMetric>> watchAssignmentMetrics({String? agentId});

  Stream<List<AgentProcessingMetric>> watchProcessingMetrics({String? agentId});

  Stream<List<AgentOrderMetric>> watchOrderMetrics({String? agentId});

  Future<void> recordPayout({
    required String agentId,
    required String agentName,
    required int amount,
    required String paymentReference,
    required String staffId,
    required String staffName,
    String? note,
  });
}
