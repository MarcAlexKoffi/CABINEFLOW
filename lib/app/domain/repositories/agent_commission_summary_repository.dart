import 'package:cabine_flow/app/domain/entities/commissions/commission_models.dart';

/// Agrégats de commissions calculés côté serveur pour ne pas charger tout
/// l'historique sur l'appareil de l'Agent.
abstract class AgentCommissionSummaryRepository {
  Stream<AgentCommissionSummary> watchAgentCommissionSummary();
}
