import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';

/// Agrégats de commissions calculés côté serveur pour ne pas charger tout
/// l'historique sur l'appareil de l'Agent.
abstract class AgentCommissionSummaryRepository {
  Stream<AgentCommissionSummary> watchAgentCommissionSummary();
}
