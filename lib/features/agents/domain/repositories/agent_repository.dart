import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';

abstract class AgentRepository {
  Stream<List<AgentDirectoryEntry>> watchAgents();

  Stream<AgentProfile?> watchAgentProfile(String agentId);

  Stream<List<AgentZone>> watchZones();

  Stream<List<AgentIssue>> watchAgentIssues(String agentId);

  Future<List<StaffAccountSummary>> loadPendingAccounts();

  Future<void> activatePendingAccountAsAgent({
    required StaffAccountSummary account,
  });

  Future<void> saveAgentAdmin({
    required AgentDirectoryEntry agent,
    required AgentAdminUpdate update,
  });

  Future<void> updateOwnOperations({
    required String agentId,
    required AgentOperationalUpdate update,
  });

  Future<String> createZone({
    required String name,
    required String city,
    required String region,
  });

  Future<void> createIssue({
    required String agentId,
    required AgentIssueDraft issue,
  });
}
