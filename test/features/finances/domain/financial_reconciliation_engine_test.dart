import 'package:cabine_flow/features/finances/domain/models/financial_reconciliation_models.dart';
import 'package:cabine_flow/features/finances/domain/services/financial_reconciliation_engine.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const FinancialReconciliationEngine engine = FinancialReconciliationEngine();
  final DateTime now = DateTime.utc(2026, 8, 31, 10);

  QueueOrder successfulOrder({
    String id = 'ORDER-001',
    DateTime? completedAt,
    QueueOrderStatus status = QueueOrderStatus.completed,
    OrderPaymentStatus paymentStatus = OrderPaymentStatus.confirmed,
  }) {
    return QueueOrder(
      id: id,
      reference: 'CF-20260831-TEST001',
      clientName: 'Client Test',
      clientWhatsappPhone: '+2250700000000',
      network: MobileNetwork.orange,
      beneficiaryPhone: '+2250700000001',
      operationType: OrderOperationType.unitTransfer,
      offerLabel: 'Transfert unités',
      amount: 1000,
      createdAt: now.subtract(const Duration(hours: 2)),
      status: status,
      paymentStatus: paymentStatus,
      paidAt: now.subtract(const Duration(hours: 1, minutes: 50)),
      paymentConfirmedAt: now.subtract(const Duration(hours: 1, minutes: 45)),
      paymentReference: 'WAVE-TEST-001',
      assignedAgentId: 'AGENT-001',
      assignedAgentName: 'Agent Test',
      assignedAt: now.subtract(const Duration(hours: 1, minutes: 30)),
      assignmentStatus: OrderAssignmentStatus.accepted,
      takenByUserId: 'AGENT-001',
      takenAt: now.subtract(const Duration(hours: 1)),
      completedAt: completedAt ?? now.subtract(const Duration(minutes: 45)),
    );
  }

  FinancialReconciliationEvidence coherentEvidence({
    String orderId = 'ORDER-001',
    DateTime? coverageStart,
    bool includeMovement = true,
    bool includeCommission = true,
    ReconciliationRefundEvidence? refund,
  }) {
    final DateTime start =
        coverageStart ?? now.subtract(const Duration(days: 1));
    return FinancialReconciliationEvidence(
      assignmentsByOrder: <String, List<ReconciliationAssignmentEvidence>>{
        orderId: <ReconciliationAssignmentEvidence>[
          ReconciliationAssignmentEvidence(
            orderId: orderId,
            agentId: 'AGENT-001',
            status: 'accepted',
            assignedAt: now.subtract(const Duration(hours: 1, minutes: 30)),
          ),
        ],
      },
      agentUserIds: const <String>{'AGENT-001'},
      eventsByOrder: <String, Set<String>>{
        orderId: const <String>{'PROCESSING_STARTED', 'PROCESSING_SUCCEEDED'},
      },
      proofOrderIds: <String>{orderId},
      networkMovementsByOrder: includeMovement
          ? <String, ReconciliationNetworkMovementEvidence>{
              orderId: ReconciliationNetworkMovementEvidence(
                orderId: orderId,
                network: 'orange',
                amount: 1000,
                agentId: 'AGENT-001',
                createdAt: now.subtract(const Duration(minutes: 45)),
              ),
            }
          : const <String, ReconciliationNetworkMovementEvidence>{},
      commissionsByOrder: includeCommission
          ? <String, ReconciliationCommissionEvidence>{
              orderId: ReconciliationCommissionEvidence(
                orderId: orderId,
                agentId: 'AGENT-001',
                orderAmount: 1000,
                commissionAmount: 10,
                earnedAt: now.subtract(const Duration(minutes: 45)),
              ),
            }
          : const <String, ReconciliationCommissionEvidence>{},
      refundsByOrder: refund == null
          ? const <String, ReconciliationRefundEvidence>{}
          : <String, ReconciliationRefundEvidence>{orderId: refund},
      creditsByOrder: const <String, ReconciliationCreditEvidence>{},
      networkMovementCoverageStart: start,
      commissionCoverageStart: start,
    );
  }

  test('Phase 14A - chaîne complète cohérente', () {
    final List<FinancialReconciliationResult> results = engine.reconcile(
      orders: <QueueOrder>[successfulOrder()],
      evidence: coherentEvidence(),
    );

    expect(results, hasLength(1));
    expect(results.single.state, FinancialReconciliationOverallState.coherent);
    expect(results.single.issues, isEmpty);
    expect(results.single.requiredChecks, 7);
    expect(results.single.coherentChecks, 7);
  });

  test('Phase 14A - sortie réseau manquante est signalée', () {
    final List<FinancialReconciliationResult> results = engine.reconcile(
      orders: <QueueOrder>[successfulOrder()],
      evidence: coherentEvidence(includeMovement: false),
    );

    expect(results.single.state, FinancialReconciliationOverallState.attention);
    expect(
      results.single.issues.any(
        (FinancialReconciliationCheck check) =>
            check.link == FinancialReconciliationLink.networkMovement,
      ),
      isTrue,
    );
  });

  test('Phase 14A - vente à crédit ne demande pas de paiement Wave', () {
    final QueueOrder creditOrder = QueueOrder(
      id: 'ORDER-CREDIT',
      reference: 'CF-20260831-CREDIT1',
      clientName: 'Client Crédit',
      clientWhatsappPhone: '+2250700000000',
      network: MobileNetwork.mtn,
      beneficiaryPhone: '+2250500000001',
      operationType: OrderOperationType.unitTransfer,
      offerLabel: 'Transfert unités',
      amount: 1500,
      createdAt: now,
      status: QueueOrderStatus.paidReady,
      paymentStatus: OrderPaymentStatus.credit,
    );

    final List<FinancialReconciliationResult> results = engine.reconcile(
      orders: <QueueOrder>[creditOrder],
      evidence: FinancialReconciliationEvidence(
        assignmentsByOrder:
            const <String, List<ReconciliationAssignmentEvidence>>{},
        agentUserIds: const <String>{},
        eventsByOrder: const <String, Set<String>>{},
        proofOrderIds: const <String>{},
        networkMovementsByOrder:
            const <String, ReconciliationNetworkMovementEvidence>{},
        commissionsByOrder: const <String, ReconciliationCommissionEvidence>{},
        refundsByOrder: const <String, ReconciliationRefundEvidence>{},
        creditsByOrder: const <String, ReconciliationCreditEvidence>{
          'ORDER-CREDIT': ReconciliationCreditEvidence(
            orderId: 'ORDER-CREDIT',
            orderReference: 'CF-20260831-CREDIT1',
            amount: 1500,
            paidAmount: 0,
            status: 'open',
          ),
        },
      ),
    );

    expect(
      results.single.state,
      FinancialReconciliationOverallState.inProgress,
    );
    expect(results.single.issues, isEmpty);
    final FinancialReconciliationCheck payment = results.single.checks
        .firstWhere(
          (FinancialReconciliationCheck check) =>
              check.link == FinancialReconciliationLink.payment,
        );
    expect(payment.state, FinancialReconciliationCheckState.coherent);
    expect(payment.detail, contains('crédit'));
  });

  test('Phase 14A - historique pré-Phase 12/13 ne crée pas de faux défaut', () {
    final DateTime oldCompletion = now.subtract(const Duration(days: 10));
    final DateTime phaseCoverage = now.subtract(const Duration(days: 2));
    final FinancialReconciliationEvidence evidence = coherentEvidence(
      coverageStart: phaseCoverage,
      includeMovement: false,
      includeCommission: false,
    );

    final List<FinancialReconciliationResult> results = engine.reconcile(
      orders: <QueueOrder>[successfulOrder(completedAt: oldCompletion)],
      evidence: evidence,
    );

    expect(results.single.state, FinancialReconciliationOverallState.coherent);
    expect(results.single.issues, isEmpty);
    expect(
      results.single.checks
          .firstWhere(
            (FinancialReconciliationCheck check) =>
                check.link == FinancialReconciliationLink.networkMovement,
          )
          .state,
      FinancialReconciliationCheckState.notApplicable,
    );
    expect(
      results.single.checks
          .firstWhere(
            (FinancialReconciliationCheck check) =>
                check.link == FinancialReconciliationLink.commission,
          )
          .state,
      FinancialReconciliationCheckState.notApplicable,
    );
  });

  test('Phase 14A - remboursement rapproché devient cohérent remboursé', () {
    final ReconciliationRefundEvidence refund = ReconciliationRefundEvidence(
      id: 'ORDER-001',
      orderId: 'ORDER-001',
      amount: 1000,
      status: 'reconciled',
      updatedAt: now,
    );

    final List<FinancialReconciliationResult> results = engine.reconcile(
      orders: <QueueOrder>[successfulOrder(status: QueueOrderStatus.refunded)],
      evidence: coherentEvidence(refund: refund),
    );

    expect(results.single.state, FinancialReconciliationOverallState.refunded);
    expect(results.single.issues, isEmpty);
    expect(results.single.refundId, 'ORDER-001');
  });
}
