import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/commissions/domain/services/commission_performance_calculator.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('100 transactions réussies valent 1000 F', () {
    final DateTime now = DateTime(2026, 8, 29, 12);
    final List<CommissionEntry> commissions = List<CommissionEntry>.generate(
      100,
      (int index) => CommissionEntry(
        id: 'order-$index',
        orderId: 'order-$index',
        orderReference: 'CF-20260829-$index',
        agentId: 'agent-1',
        agentName: 'Marc Koffi',
        network: MobileNetwork.orange,
        orderAmount: 1000,
        commissionAmount: 10,
        policyId: CommissionPolicy.current.id,
        policyType: CommissionPolicy.current.type,
        rate: 10,
        earnedAt: now,
        processingStartedAt: now.subtract(const Duration(minutes: 2)),
      ),
    );
    final List<AgentAssignmentMetric> assignments =
        List<AgentAssignmentMetric>.generate(
          100,
          (int index) => AgentAssignmentMetric(
            id: 'assignment-$index',
            orderId: 'order-$index',
            agentId: 'agent-1',
            status: 'accepted',
            assignedAt: now,
            acceptedAt: now,
            completedAt: now,
          ),
        );

    final List<AgentProcessingMetric> processing =
        List<AgentProcessingMetric>.generate(
          100,
          (int index) => AgentProcessingMetric(
            id: 'success-event-$index',
            orderId: 'order-$index',
            agentId: 'agent-1',
            type: 'PROCESSING_SUCCEEDED',
            createdAt: now,
          ),
        );
    final List<AgentOrderMetric> orders = List<AgentOrderMetric>.generate(
      100,
      (int index) => AgentOrderMetric(
        orderId: 'order-$index',
        agentId: 'agent-1',
        amount: 1000,
        status: 'completed',
        createdAt: now.subtract(const Duration(minutes: 4)),
        takenAt: now.subtract(const Duration(minutes: 2)),
        completedAt: now,
      ),
    );

    final AgentPerformanceSnapshot result =
        CommissionPerformanceCalculator.build(
          agentId: 'agent-1',
          period: CommissionPeriod.thisMonth,
          commissions: commissions,
          payouts: const <CommissionPayout>[],
          assignments: assignments,
          processingEvents: processing,
          orderMetrics: orders,
          now: now,
        );

    expect(result.transactionsSuccessful, 100);
    expect(result.commissionGeneratedInPeriod, 1000);
    expect(result.totalCommissionEarned, 1000);
    expect(result.commissionBalance, 1000);
    expect(result.amountProcessed, 100000);
    expect(result.averageProcessingDuration, const Duration(minutes: 2));
  });

  test(
    'le taux de réussite exclut les refus et les commandes encore actives',
    () {
      final DateTime now = DateTime(2026, 8, 29, 12);
      final List<CommissionEntry> commissions = <CommissionEntry>[
        for (int index = 0; index < 8; index++)
          CommissionEntry(
            id: 'success-$index',
            orderId: 'success-$index',
            orderReference: 'CF-SUCCESS-$index',
            agentId: 'agent-1',
            agentName: 'Agent Un',
            network: MobileNetwork.mtn,
            orderAmount: 500,
            commissionAmount: 10,
            policyId: CommissionPolicy.current.id,
            policyType: CommissionPolicy.current.type,
            rate: 10,
            earnedAt: now,
          ),
      ];
      final List<AgentAssignmentMetric> assignments = <AgentAssignmentMetric>[
        for (int index = 0; index < 12; index++)
          AgentAssignmentMetric(
            id: 'a-$index',
            orderId: 'o-$index',
            agentId: 'agent-1',
            status: index == 8 ? 'refused' : 'accepted',
            assignedAt: now,
          ),
      ];
      final List<AgentProcessingMetric> processing = <AgentProcessingMetric>[
        for (int index = 0; index < 8; index++)
          AgentProcessingMetric(
            id: 'success-$index',
            orderId: 'success-$index',
            agentId: 'agent-1',
            type: 'PROCESSING_SUCCEEDED',
            createdAt: now,
          ),
        AgentProcessingMetric(
          id: 'failed-1',
          orderId: 'failed-order',
          agentId: 'agent-1',
          type: 'PROCESSING_FAILED',
          createdAt: now,
        ),
      ];
      final List<AgentOrderMetric> orders = <AgentOrderMetric>[
        for (int index = 0; index < 8; index++)
          AgentOrderMetric(
            orderId: 'success-$index',
            agentId: 'agent-1',
            amount: 500,
            status: 'completed',
            createdAt: now,
            takenAt: now.subtract(const Duration(minutes: 1)),
            completedAt: now,
          ),
      ];

      final AgentPerformanceSnapshot result =
          CommissionPerformanceCalculator.build(
            agentId: 'agent-1',
            period: CommissionPeriod.today,
            commissions: commissions,
            payouts: const <CommissionPayout>[],
            assignments: assignments,
            processingEvents: processing,
            orderMetrics: orders,
            now: now,
          );

      expect(result.transactionsReceived, 12);
      expect(result.transactionsSuccessful, 8);
      expect(result.transactionsRefused, 1);
      expect(result.transactionsFailed, 1);
      expect(result.transactionsOther, 2);
      expect(result.successRate, closeTo(8 / 9, 0.0001));
    },
  );

  test('le temps moyen privilégie les vraies traces PROCESSING_STARTED', () {
    final DateTime now = DateTime(2026, 8, 29, 12);
    final AgentPerformanceSnapshot result =
        CommissionPerformanceCalculator.build(
          agentId: 'agent-1',
          period: CommissionPeriod.today,
          commissions: const <CommissionEntry>[],
          payouts: const <CommissionPayout>[],
          assignments: <AgentAssignmentMetric>[
            AgentAssignmentMetric(
              id: 'a-1',
              orderId: 'order-1',
              agentId: 'agent-1',
              status: 'accepted',
              assignedAt: now.subtract(const Duration(minutes: 10)),
            ),
          ],
          processingEvents: <AgentProcessingMetric>[
            AgentProcessingMetric(
              id: 'start-1',
              orderId: 'order-1',
              agentId: 'agent-1',
              type: 'PROCESSING_STARTED',
              createdAt: now.subtract(const Duration(minutes: 4)),
            ),
            AgentProcessingMetric(
              id: 'success-1',
              orderId: 'order-1',
              agentId: 'agent-1',
              type: 'PROCESSING_SUCCEEDED',
              createdAt: now,
            ),
          ],
          orderMetrics: <AgentOrderMetric>[
            AgentOrderMetric(
              orderId: 'order-1',
              agentId: 'agent-1',
              amount: 1000,
              status: 'awaitingCustomerConfirmation',
              createdAt: now.subtract(const Duration(hours: 1)),
              takenAt: now.subtract(const Duration(minutes: 20)),
              completedAt: now,
            ),
          ],
          now: now,
        );

    expect(result.averageProcessingDuration, const Duration(minutes: 4));
  });
}
