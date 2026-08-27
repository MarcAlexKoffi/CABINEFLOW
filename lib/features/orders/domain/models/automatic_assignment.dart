import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

class AutomaticAssignmentQueueItem {
  const AutomaticAssignmentQueueItem({
    required this.orderId,
    required this.orderReference,
    required this.network,
    required this.amount,
    required this.createdAt,
    this.lastRefusedAgentId,
  });

  final String orderId;
  final String orderReference;
  final MobileNetwork network;
  final int amount;
  final DateTime createdAt;
  final String? lastRefusedAgentId;
}

class AutomaticAssignmentAgent {
  const AutomaticAssignmentAgent({
    required this.agentId,
    required this.name,
    required this.isActive,
    required this.isAvailable,
    required this.authorizedNetworks,
    required this.activeNetworks,
    required this.orangeCapacity,
    required this.mtnCapacity,
    required this.moovCapacity,
    required this.dailyTransactionLimit,
    required this.maxTransactionsPerDay,
    required this.activeAssignmentCount,
    required this.orangeReservedAmount,
    required this.mtnReservedAmount,
    required this.moovReservedAmount,
    required this.todayAssignmentCount,
    required this.todayAssignedAmount,
    this.lastAssignedAt,
  });

  final String agentId;
  final String name;
  final bool isActive;
  final bool isAvailable;
  final Set<MobileNetwork> authorizedNetworks;
  final Set<MobileNetwork> activeNetworks;
  final int orangeCapacity;
  final int mtnCapacity;
  final int moovCapacity;
  final int dailyTransactionLimit;
  final int maxTransactionsPerDay;
  final int activeAssignmentCount;
  final int orangeReservedAmount;
  final int mtnReservedAmount;
  final int moovReservedAmount;
  final int todayAssignmentCount;
  final int todayAssignedAmount;
  final DateTime? lastAssignedAt;

  int capacityFor(MobileNetwork network) {
    switch (network) {
      case MobileNetwork.orange:
        return orangeCapacity;
      case MobileNetwork.mtn:
        return mtnCapacity;
      case MobileNetwork.moov:
        return moovCapacity;
    }
  }

  int reservedFor(MobileNetwork network) {
    switch (network) {
      case MobileNetwork.orange:
        return orangeReservedAmount;
      case MobileNetwork.mtn:
        return mtnReservedAmount;
      case MobileNetwork.moov:
        return moovReservedAmount;
    }
  }

  int availableCapacityFor(MobileNetwork network) {
    final int available = capacityFor(network) - reservedFor(network);
    return available < 0 ? 0 : available;
  }

  String? ineligibilityReason({required QueueOrder order}) {
    if (!isActive) return 'agent-inactive';
    if (!isAvailable) return 'agent-unavailable';
    if (!authorizedNetworks.contains(order.network)) {
      return 'network-not-authorized';
    }
    if (!activeNetworks.contains(order.network)) {
      return 'network-disabled';
    }
    if (availableCapacityFor(order.network) < order.amount) {
      return 'insufficient-capacity';
    }
    if (order.lastAssignmentRefusedAgentId == agentId) {
      return 'just-refused-this-order';
    }

    // Une valeur 0 signifie « aucune limite configurée ». C'est important
    // pour les profils agents créés avant l'introduction des limites 9E :
    // ils doivent rester éligibles au lieu d'être silencieusement exclus.
    if (maxTransactionsPerDay > 0 &&
        todayAssignmentCount >= maxTransactionsPerDay) {
      return 'daily-count-limit-reached';
    }
    if (dailyTransactionLimit > 0 &&
        todayAssignedAmount + order.amount > dailyTransactionLimit) {
      return 'daily-amount-limit-reached';
    }
    return null;
  }

  bool canReceive({required QueueOrder order}) {
    return ineligibilityReason(order: order) == null;
  }
}
