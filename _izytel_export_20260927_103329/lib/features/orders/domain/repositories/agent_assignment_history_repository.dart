import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

/// Historique d'affectation propre à l'Agent.
///
/// Séparé de [OrdersRepository] pour ne pas imposer cette source de données
/// aux dépôts purement Firebase ou aux doubles de test qui n'en ont pas besoin.
abstract class AgentAssignmentHistoryRepository {
  Stream<List<QueueOrder>> watchAgentRefusedOrders({required String agentId});
}
