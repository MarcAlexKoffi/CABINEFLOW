import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

enum CommissionPolicyType { fixedPerSuccessfulTransaction }

class CommissionPolicy {
  const CommissionPolicy({
    required this.id,
    required this.type,
    required this.amountPerSuccessfulTransaction,
  });

  static const CommissionPolicy current = CommissionPolicy(
    id: 'fixed-10-v1',
    type: CommissionPolicyType.fixedPerSuccessfulTransaction,
    amountPerSuccessfulTransaction: 10,
  );

  final String id;
  final CommissionPolicyType type;
  final int amountPerSuccessfulTransaction;

  String get label => '$amountPerSuccessfulTransaction F / transaction réussie';
}

enum CommissionPeriod { today, last7Days, thisMonth }

extension CommissionPeriodX on CommissionPeriod {
  String get label {
    switch (this) {
      case CommissionPeriod.today:
        return 'Aujourd’hui';
      case CommissionPeriod.last7Days:
        return '7 jours';
      case CommissionPeriod.thisMonth:
        return 'Ce mois';
    }
  }

  DateTime start(DateTime now) {
    switch (this) {
      case CommissionPeriod.today:
        return DateTime(now.year, now.month, now.day);
      case CommissionPeriod.last7Days:
        final DateTime today = DateTime(now.year, now.month, now.day);
        return today.subtract(const Duration(days: 6));
      case CommissionPeriod.thisMonth:
        return DateTime(now.year, now.month);
    }
  }

  bool contains(DateTime value, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final DateTime periodStart = start(reference);
    final DateTime periodEnd = DateTime(
      reference.year,
      reference.month,
      reference.day,
      23,
      59,
      59,
      999,
    );
    return !value.isBefore(periodStart) && !value.isAfter(periodEnd);
  }
}

class CommissionEntry {
  const CommissionEntry({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.agentId,
    required this.agentName,
    required this.network,
    required this.orderAmount,
    required this.commissionAmount,
    required this.policyId,
    required this.policyType,
    required this.rate,
    required this.earnedAt,
    this.processingStartedAt,
  });

  final String id;
  final String orderId;
  final String orderReference;
  final String agentId;
  final String agentName;
  final MobileNetwork network;
  final int orderAmount;
  final int commissionAmount;
  final String policyId;
  final CommissionPolicyType policyType;
  final int rate;
  final DateTime earnedAt;
  final DateTime? processingStartedAt;

  Duration? get processingDuration {
    final DateTime? startedAt = processingStartedAt;
    if (startedAt == null || earnedAt.isBefore(startedAt)) {
      return null;
    }
    return earnedAt.difference(startedAt);
  }
}

class CommissionPayout {
  const CommissionPayout({
    required this.id,
    required this.agentId,
    required this.agentName,
    required this.amount,
    required this.paymentChannel,
    required this.paymentReference,
    required this.paidAt,
    required this.createdBy,
    required this.createdByName,
    this.note,
  });

  final String id;
  final String agentId;
  final String agentName;
  final int amount;
  final String paymentChannel;
  final String paymentReference;
  final DateTime paidAt;
  final String createdBy;
  final String createdByName;
  final String? note;
}

class CommissionAccount {
  const CommissionAccount({
    required this.agentId,
    required this.agentName,
    required this.earnedTotal,
    required this.paidTotal,
    required this.earnedTransactions,
    required this.updatedAt,
  });

  final String agentId;
  final String agentName;
  final int earnedTotal;
  final int paidTotal;
  final int earnedTransactions;
  final DateTime updatedAt;

  int get balance => earnedTotal - paidTotal;
}

class AgentAssignmentMetric {
  const AgentAssignmentMetric({
    required this.id,
    required this.orderId,
    required this.agentId,
    required this.status,
    required this.assignedAt,
    this.acceptedAt,
    this.refusedAt,
    this.completedAt,
  });

  final String id;
  final String orderId;
  final String agentId;
  final String status;
  final DateTime assignedAt;
  final DateTime? acceptedAt;
  final DateTime? refusedAt;
  final DateTime? completedAt;
}

class AgentProcessingMetric {
  const AgentProcessingMetric({
    required this.id,
    required this.orderId,
    required this.agentId,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final String agentId;
  final String type;
  final DateTime createdAt;

  bool get isStart => type == 'PROCESSING_STARTED';
  bool get isFailure => type == 'PROCESSING_FAILED';
  bool get isSuccess => type == 'PROCESSING_SUCCEEDED';
}

class AgentOrderMetric {
  const AgentOrderMetric({
    required this.orderId,
    required this.agentId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.takenAt,
    this.completedAt,
  });

  final String orderId;
  final String agentId;
  final int amount;
  final String status;
  final DateTime createdAt;
  final DateTime? takenAt;
  final DateTime? completedAt;
}

class AgentPerformanceSnapshot {
  const AgentPerformanceSnapshot({
    required this.agentId,
    required this.period,
    required this.transactionsReceived,
    required this.transactionsSuccessful,
    required this.transactionsRefused,
    required this.transactionsFailed,
    required this.transactionsOther,
    required this.amountProcessed,
    required this.commissionGeneratedInPeriod,
    required this.commissionPaidInPeriod,
    required this.totalCommissionEarned,
    required this.totalCommissionPaid,
    required this.commissionBalance,
    required this.averageProcessingDuration,
  });

  final String agentId;
  final CommissionPeriod period;
  final int transactionsReceived;
  final int transactionsSuccessful;
  final int transactionsRefused;
  final int transactionsFailed;
  final int transactionsOther;
  final int amountProcessed;
  final int commissionGeneratedInPeriod;
  final int commissionPaidInPeriod;
  final int totalCommissionEarned;
  final int totalCommissionPaid;
  final int commissionBalance;
  final Duration? averageProcessingDuration;

  double get successRate {
    final int completed = transactionsSuccessful + transactionsFailed;
    if (completed <= 0) return 0;
    return transactionsSuccessful / completed;
  }
}
