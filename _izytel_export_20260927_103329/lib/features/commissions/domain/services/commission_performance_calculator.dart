import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';

class CommissionPerformanceCalculator {
  const CommissionPerformanceCalculator._();

  static AgentPerformanceSnapshot build({
    required String agentId,
    required CommissionPeriod period,
    required List<CommissionEntry> commissions,
    required List<CommissionPayout> payouts,
    required List<AgentAssignmentMetric> assignments,
    required List<AgentProcessingMetric> processingEvents,
    required List<AgentOrderMetric> orderMetrics,
    DateTime? now,
  }) {
    final DateTime reference = now ?? DateTime.now();
    final List<CommissionEntry> ownCommissions = commissions
        .where((CommissionEntry value) => value.agentId == agentId)
        .toList(growable: false);
    final List<CommissionPayout> ownPayouts = payouts
        .where((CommissionPayout value) => value.agentId == agentId)
        .toList(growable: false);

    final List<AgentOrderMetric> ownOrders = orderMetrics
        .where((AgentOrderMetric value) => value.agentId == agentId)
        .toList(growable: false);

    final List<CommissionEntry> periodCommissions = ownCommissions
        .where(
          (CommissionEntry value) =>
              period.contains(value.earnedAt, now: reference),
        )
        .toList(growable: false);
    final List<CommissionPayout> periodPayouts = ownPayouts
        .where(
          (CommissionPayout value) =>
              period.contains(value.paidAt, now: reference),
        )
        .toList(growable: false);
    final List<AgentAssignmentMetric> periodAssignments = assignments
        .where(
          (AgentAssignmentMetric value) =>
              value.agentId == agentId &&
              period.contains(value.assignedAt, now: reference),
        )
        .toList(growable: false);
    final List<AgentProcessingMetric> ownProcessing = processingEvents
        .where((AgentProcessingMetric value) => value.agentId == agentId)
        .toList(growable: false);
    final List<AgentProcessingMetric> periodProcessing = ownProcessing
        .where(
          (AgentProcessingMetric value) =>
              period.contains(value.createdAt, now: reference),
        )
        .toList(growable: false);

    final List<AgentProcessingMetric> successEvents = periodProcessing
        .where((AgentProcessingMetric value) => value.isSuccess)
        .toList(growable: false);
    final Set<String> successfulOrderIds = successEvents
        .map((AgentProcessingMetric value) => value.orderId)
        .toSet();
    final int successful = successEvents.length;
    final int refused = periodAssignments
        .where((AgentAssignmentMetric value) => value.status == 'refused')
        .length;
    final int failed = periodProcessing
        .where((AgentProcessingMetric value) => value.isFailure)
        .length;
    final int received = periodAssignments.length;
    final int other = (received - successful - refused - failed)
        .clamp(0, received)
        .toInt();

    final List<AgentOrderMetric> successfulOrders = ownOrders
        .where(
          (AgentOrderMetric value) =>
              successfulOrderIds.contains(value.orderId),
        )
        .toList(growable: false);
    final int amountProcessed = successfulOrders.fold<int>(
      0,
      (int total, AgentOrderMetric value) => total + value.amount,
    );
    final int generatedInPeriod = periodCommissions.fold<int>(
      0,
      (int total, CommissionEntry value) => total + value.commissionAmount,
    );
    final int paidInPeriod = periodPayouts.fold<int>(
      0,
      (int total, CommissionPayout value) => total + value.amount,
    );
    final int earnedTotal = ownCommissions.fold<int>(
      0,
      (int total, CommissionEntry value) => total + value.commissionAmount,
    );
    final int paidTotal = ownPayouts.fold<int>(
      0,
      (int total, CommissionPayout value) => total + value.amount,
    );

    final Map<String, AgentOrderMetric> orderById = <String, AgentOrderMetric>{
      for (final AgentOrderMetric value in ownOrders) value.orderId: value,
    };
    final List<Duration> durations = successEvents
        .map((AgentProcessingMetric success) {
          final List<AgentProcessingMetric> starts =
              ownProcessing
                  .where(
                    (AgentProcessingMetric value) =>
                        value.isStart &&
                        value.orderId == success.orderId &&
                        !value.createdAt.isAfter(success.createdAt),
                  )
                  .toList(growable: false)
                ..sort(
                  (AgentProcessingMetric first, AgentProcessingMetric second) =>
                      second.createdAt.compareTo(first.createdAt),
                );
          if (starts.isNotEmpty) {
            return success.createdAt.difference(starts.first.createdAt);
          }

          // Compatibilité avec les anciennes commandes si une trace de début
          // manque : on retombe sur les timestamps métier déjà enregistrés.
          final AgentOrderMetric? order = orderById[success.orderId];
          final DateTime? startedAt = order?.takenAt;
          final DateTime? completedAt = order?.completedAt;
          if (startedAt == null ||
              completedAt == null ||
              completedAt.isBefore(startedAt)) {
            return null;
          }
          return completedAt.difference(startedAt);
        })
        .whereType<Duration>()
        .where((Duration value) => !value.isNegative)
        .toList(growable: false);
    Duration? averageDuration;
    if (durations.isNotEmpty) {
      final int totalMilliseconds = durations.fold<int>(
        0,
        (int total, Duration value) => total + value.inMilliseconds,
      );
      averageDuration = Duration(
        milliseconds: totalMilliseconds ~/ durations.length,
      );
    }

    return AgentPerformanceSnapshot(
      agentId: agentId,
      period: period,
      transactionsReceived: received,
      transactionsSuccessful: successful,
      transactionsRefused: refused,
      transactionsFailed: failed,
      transactionsOther: other,
      amountProcessed: amountProcessed,
      commissionGeneratedInPeriod: generatedInPeriod,
      commissionPaidInPeriod: paidInPeriod,
      totalCommissionEarned: earnedTotal,
      totalCommissionPaid: paidTotal,
      commissionBalance: (earnedTotal - paidTotal)
          .clamp(0, earnedTotal)
          .toInt(),
      averageProcessingDuration: averageDuration,
    );
  }
}
