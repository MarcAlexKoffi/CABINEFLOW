import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

enum FinancialReconciliationCheckState { coherent, attention, notApplicable }

enum FinancialReconciliationLink {
  payment,
  assignment,
  agent,
  processing,
  proof,
  networkMovement,
  commission,
  refund,
}

enum FinancialReconciliationOverallState {
  attention,
  coherent,
  inProgress,
  refunded,
}

class FinancialReconciliationCheck {
  const FinancialReconciliationCheck({
    required this.link,
    required this.label,
    required this.state,
    required this.detail,
  });

  final FinancialReconciliationLink link;
  final String label;
  final FinancialReconciliationCheckState state;
  final String detail;

  bool get isRequired =>
      state != FinancialReconciliationCheckState.notApplicable;
  bool get isCoherent => state == FinancialReconciliationCheckState.coherent;
  bool get needsAttention =>
      state == FinancialReconciliationCheckState.attention;
}

class FinancialReconciliationResult {
  const FinancialReconciliationResult({
    required this.order,
    required this.state,
    required this.date,
    required this.checks,
    this.refundId,
    this.refundStatus,
  });

  final QueueOrder order;
  final FinancialReconciliationOverallState state;
  final DateTime date;
  final List<FinancialReconciliationCheck> checks;
  final String? refundId;
  final String? refundStatus;

  List<FinancialReconciliationCheck> get issues => checks
      .where((FinancialReconciliationCheck item) => item.needsAttention)
      .toList(growable: false);

  int get requiredChecks => checks
      .where((FinancialReconciliationCheck item) => item.isRequired)
      .length;

  int get coherentChecks => checks
      .where((FinancialReconciliationCheck item) => item.isCoherent)
      .length;

  bool get needsAttention => issues.isNotEmpty;
}

class ReconciliationAssignmentEvidence {
  const ReconciliationAssignmentEvidence({
    required this.orderId,
    required this.agentId,
    required this.status,
    required this.assignedAt,
  });

  final String orderId;
  final String agentId;
  final String status;
  final DateTime? assignedAt;
}

class ReconciliationNetworkMovementEvidence {
  const ReconciliationNetworkMovementEvidence({
    required this.orderId,
    required this.network,
    required this.amount,
    required this.agentId,
    required this.createdAt,
  });

  final String orderId;
  final String network;
  final int amount;
  final String? agentId;
  final DateTime? createdAt;
}

class ReconciliationCommissionEvidence {
  const ReconciliationCommissionEvidence({
    required this.orderId,
    required this.agentId,
    required this.orderAmount,
    required this.commissionAmount,
    required this.earnedAt,
  });

  final String orderId;
  final String agentId;
  final int orderAmount;
  final int commissionAmount;
  final DateTime? earnedAt;
}

class ReconciliationRefundEvidence {
  const ReconciliationRefundEvidence({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final String orderId;
  final int amount;
  final String status;
  final DateTime? updatedAt;
}

class ReconciliationCreditEvidence {
  const ReconciliationCreditEvidence({
    required this.orderId,
    required this.orderReference,
    required this.amount,
    required this.paidAmount,
    required this.status,
  });

  final String orderId;
  final String orderReference;
  final int amount;
  final int paidAmount;
  final String status;
}

class FinancialReconciliationEvidence {
  const FinancialReconciliationEvidence({
    required this.assignmentsByOrder,
    required this.agentUserIds,
    required this.eventsByOrder,
    required this.proofOrderIds,
    required this.networkMovementsByOrder,
    required this.commissionsByOrder,
    required this.refundsByOrder,
    required this.creditsByOrder,
    this.networkMovementCoverageStart,
    this.commissionCoverageStart,
  });

  final Map<String, List<ReconciliationAssignmentEvidence>> assignmentsByOrder;
  final Set<String> agentUserIds;
  final Map<String, Set<String>> eventsByOrder;
  final Set<String> proofOrderIds;
  final Map<String, ReconciliationNetworkMovementEvidence>
  networkMovementsByOrder;
  final Map<String, ReconciliationCommissionEvidence> commissionsByOrder;
  final Map<String, ReconciliationRefundEvidence> refundsByOrder;
  final Map<String, ReconciliationCreditEvidence> creditsByOrder;
  final DateTime? networkMovementCoverageStart;
  final DateTime? commissionCoverageStart;
}
