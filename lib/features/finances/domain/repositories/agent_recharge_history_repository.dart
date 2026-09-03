import 'package:cabine_flow/features/finances/domain/models/agent_recharge_history_models.dart';

abstract class AgentRechargeHistoryRepository {
  Future<AgentRechargeHistoryPageData> fetchPage({
    required String agentId,
    AgentRechargeHistoryCursor? cursor,
    AgentRechargeHistoryFilter filter = const AgentRechargeHistoryFilter(),
    int pageSize = 50,
  });

  Future<AgentRechargeHistorySummary> fetchSummary({
    required String agentId,
    AgentRechargeHistoryFilter filter = const AgentRechargeHistoryFilter(),
  });
}
