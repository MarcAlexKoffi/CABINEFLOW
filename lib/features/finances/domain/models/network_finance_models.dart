import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';

enum NetworkTransactionDirection { incoming, outgoing }

enum NetworkTransactionType { orderSuccess, supplierRecharge, manualAdjustment }

class NetworkTransaction {
  const NetworkTransaction({
    required this.id,
    required this.network,
    required this.direction,
    required this.type,
    required this.amount,
    required this.capacityBefore,
    required this.capacityAfter,
    required this.createdBy,
    required this.createdByRole,
    required this.createdAt,
    this.agentId,
    this.agentName,
    this.orderId,
    this.orderReference,
    this.supplierId,
    this.supplierName,
    this.supplierRechargeId,
  });

  final String id;
  final AgentNetwork network;
  final NetworkTransactionDirection direction;
  final NetworkTransactionType type;
  final int amount;
  final int capacityBefore;
  final int capacityAfter;
  final String? agentId;
  final String? agentName;
  final String? orderId;
  final String? orderReference;
  final String? supplierId;
  final String? supplierName;
  final String? supplierRechargeId;
  final String createdBy;
  final String createdByRole;
  final DateTime createdAt;

  bool get isIncoming => direction == NetworkTransactionDirection.incoming;
  bool get isOutgoing => direction == NetworkTransactionDirection.outgoing;
}

class NetworkFundSnapshot {
  const NetworkFundSnapshot({
    required this.network,
    required this.available,
    required this.committed,
    required this.totalIncoming,
    required this.totalOutgoing,
  });

  final AgentNetwork network;
  final int available;
  final int committed;
  final int totalIncoming;
  final int totalOutgoing;
}
