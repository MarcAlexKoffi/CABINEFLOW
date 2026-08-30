import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/finances/domain/models/network_finance_models.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

class NetworkFinanceCalculator {
  const NetworkFinanceCalculator._();

  static Map<AgentNetwork, NetworkFundSnapshot> calculate({
    required List<AgentDirectoryEntry> agents,
    required List<QueueOrder> orders,
    required List<NetworkTransaction> transactions,
  }) {
    final Map<AgentNetwork, int> available = <AgentNetwork, int>{
      for (final AgentNetwork network in AgentNetwork.values) network: 0,
    };
    final Map<AgentNetwork, int> committed = <AgentNetwork, int>{
      for (final AgentNetwork network in AgentNetwork.values) network: 0,
    };
    final Map<AgentNetwork, int> incoming = <AgentNetwork, int>{
      for (final AgentNetwork network in AgentNetwork.values) network: 0,
    };
    final Map<AgentNetwork, int> outgoing = <AgentNetwork, int>{
      for (final AgentNetwork network in AgentNetwork.values) network: 0,
    };

    for (final AgentDirectoryEntry agent in agents) {
      final AgentProfile? profile = agent.profile;
      if (!agent.isActive || profile == null) continue;
      for (final AgentNetwork network in AgentNetwork.values) {
        available[network] = available[network]! + profile.capacityFor(network);
      }
    }

    for (final QueueOrder order in orders) {
      if (!_isCommitted(order)) continue;
      final AgentNetwork network = _agentNetwork(order.network);
      committed[network] = committed[network]! + order.amount;
    }

    for (final NetworkTransaction transaction in transactions) {
      final Map<AgentNetwork, int> bucket = transaction.isIncoming
          ? incoming
          : outgoing;
      bucket[transaction.network] =
          bucket[transaction.network]! + transaction.amount;
    }

    return <AgentNetwork, NetworkFundSnapshot>{
      for (final AgentNetwork network in AgentNetwork.values)
        network: NetworkFundSnapshot(
          network: network,
          available: available[network]!,
          committed: committed[network]!,
          totalIncoming: incoming[network]!,
          totalOutgoing: outgoing[network]!,
        ),
    };
  }

  static bool _isCommitted(QueueOrder order) {
    if (order.paymentStatus != OrderPaymentStatus.confirmed) return false;
    if (!order.isAssignedToAgent) return false;
    return order.status == QueueOrderStatus.paidReady ||
        order.status == QueueOrderStatus.inProgress ||
        order.status == QueueOrderStatus.onHold;
  }

  static AgentNetwork _agentNetwork(MobileNetwork network) {
    switch (network) {
      case MobileNetwork.orange:
        return AgentNetwork.orange;
      case MobileNetwork.mtn:
        return AgentNetwork.mtn;
      case MobileNetwork.moov:
        return AgentNetwork.moov;
    }
  }
}
