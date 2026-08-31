import 'package:cabine_flow/features/finances/domain/models/financial_reconciliation_models.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

class FinancialReconciliationEngine {
  const FinancialReconciliationEngine();

  List<FinancialReconciliationResult> reconcile({
    required List<QueueOrder> orders,
    required FinancialReconciliationEvidence evidence,
  }) {
    final List<FinancialReconciliationResult> results = orders
        .where((QueueOrder order) => _isFinanciallyRelevant(order, evidence))
        .map(
          (QueueOrder order) => _reconcileOrder(
            order: order,
            evidence: evidence,
          ),
        )
        .toList(growable: false)
      ..sort(
        (FinancialReconciliationResult a, FinancialReconciliationResult b) =>
            b.date.compareTo(a.date),
      );
    return results;
  }

  bool _isFinanciallyRelevant(
    QueueOrder order,
    FinancialReconciliationEvidence evidence,
  ) {
    if (order.paymentStatus == OrderPaymentStatus.confirmed ||
        order.paymentStatus == OrderPaymentStatus.credit ||
        order.paymentStatus == OrderPaymentStatus.declared) {
      return true;
    }
    if (evidence.refundsByOrder.containsKey(order.id) ||
        evidence.creditsByOrder.containsKey(order.id)) {
      return true;
    }
    return order.status == QueueOrderStatus.paidReady ||
        order.status == QueueOrderStatus.inProgress ||
        order.status == QueueOrderStatus.onHold ||
        order.status == QueueOrderStatus.awaitingCustomerConfirmation ||
        order.status == QueueOrderStatus.completed ||
        order.status == QueueOrderStatus.failed ||
        order.status == QueueOrderStatus.refundPending ||
        order.status == QueueOrderStatus.refunded;
  }

  FinancialReconciliationResult _reconcileOrder({
    required QueueOrder order,
    required FinancialReconciliationEvidence evidence,
  }) {
    final ReconciliationRefundEvidence? refund =
        evidence.refundsByOrder[order.id];
    final List<FinancialReconciliationCheck> checks =
        <FinancialReconciliationCheck>[
          _paymentCheck(order, evidence),
          _assignmentCheck(order, evidence),
          _agentCheck(order, evidence),
          _processingCheck(order, evidence),
          _proofCheck(order, evidence),
          _networkMovementCheck(order, evidence),
          _commissionCheck(order, evidence),
          _refundCheck(order, refund),
        ];

    final bool hasIssue = checks.any(
      (FinancialReconciliationCheck check) => check.needsAttention,
    );

    final FinancialReconciliationOverallState state;
    if (hasIssue) {
      state = FinancialReconciliationOverallState.attention;
    } else if (refund?.status == 'reconciled') {
      state = FinancialReconciliationOverallState.refunded;
    } else if (order.status == QueueOrderStatus.completed) {
      state = FinancialReconciliationOverallState.coherent;
    } else {
      state = FinancialReconciliationOverallState.inProgress;
    }

    final DateTime date =
        refund?.updatedAt ??
        order.completedAt ??
        order.paymentConfirmedAt ??
        order.paidAt ??
        order.paymentDeclaredAt ??
        order.assignedAt ??
        order.createdAt;

    return FinancialReconciliationResult(
      order: order,
      state: state,
      date: date,
      checks: checks,
      refundId: refund?.id,
      refundStatus: refund?.status,
    );
  }

  FinancialReconciliationCheck _paymentCheck(
    QueueOrder order,
    FinancialReconciliationEvidence evidence,
  ) {
    if (order.paymentStatus == OrderPaymentStatus.confirmed) {
      final bool hasConfirmation = order.paymentConfirmedAt != null;
      final bool hasReference = order.paymentReference?.trim().isNotEmpty == true;
      if (hasConfirmation && hasReference) {
        return const FinancialReconciliationCheck(
          link: FinancialReconciliationLink.payment,
          label: 'Paiement client',
          state: FinancialReconciliationCheckState.coherent,
          detail: 'Paiement confirmé avec date et référence.',
        );
      }
      final List<String> missing = <String>[
        if (!hasConfirmation) 'date de confirmation',
        if (!hasReference) 'référence de paiement',
      ];
      return FinancialReconciliationCheck(
        link: FinancialReconciliationLink.payment,
        label: 'Paiement client',
        state: FinancialReconciliationCheckState.attention,
        detail: 'Paiement confirmé mais ${missing.join(' et ')} manquante(s).',
      );
    }

    if (order.paymentStatus == OrderPaymentStatus.credit) {
      final ReconciliationCreditEvidence? credit = evidence.creditsByOrder[order.id];
      if (credit == null) {
        return const FinancialReconciliationCheck(
          link: FinancialReconciliationLink.payment,
          label: 'Financement client',
          state: FinancialReconciliationCheckState.attention,
          detail: 'Commande à crédit sans dossier customerCredits lié.',
        );
      }
      final bool matches = credit.orderReference == order.reference &&
          credit.amount == order.amount;
      return FinancialReconciliationCheck(
        link: FinancialReconciliationLink.payment,
        label: 'Financement client',
        state: matches
            ? FinancialReconciliationCheckState.coherent
            : FinancialReconciliationCheckState.attention,
        detail: matches
            ? 'Vente à crédit reliée au dossier client.'
            : 'Le dossier de crédit ne correspond pas au montant ou à la référence de la commande.',
      );
    }

    if (order.paymentStatus == OrderPaymentStatus.declared) {
      return const FinancialReconciliationCheck(
        link: FinancialReconciliationLink.payment,
        label: 'Paiement client',
        state: FinancialReconciliationCheckState.attention,
        detail: 'Paiement déclaré mais pas encore confirmé.',
      );
    }

    if (_hasProgressedBeyondPayment(order)) {
      return const FinancialReconciliationCheck(
        link: FinancialReconciliationLink.payment,
        label: 'Paiement client',
        state: FinancialReconciliationCheckState.attention,
        detail: 'La commande a progressé sans paiement confirmé ni crédit autorisé.',
      );
    }

    return const FinancialReconciliationCheck(
      link: FinancialReconciliationLink.payment,
      label: 'Paiement client',
      state: FinancialReconciliationCheckState.notApplicable,
      detail: 'Commande encore en attente de financement.',
    );
  }

  FinancialReconciliationCheck _assignmentCheck(
    QueueOrder order,
    FinancialReconciliationEvidence evidence,
  ) {
    final String? agentId = _clean(order.assignedAgentId);
    final List<ReconciliationAssignmentEvidence> assignments =
        evidence.assignmentsByOrder[order.id] ??
        const <ReconciliationAssignmentEvidence>[];

    if (agentId == null) {
      if (_requiresAgentLink(order)) {
        return const FinancialReconciliationCheck(
          link: FinancialReconciliationLink.assignment,
          label: 'Affectation',
          state: FinancialReconciliationCheckState.attention,
          detail: 'Commande avancée sans Agent actuellement relié.',
        );
      }
      return const FinancialReconciliationCheck(
        link: FinancialReconciliationLink.assignment,
        label: 'Affectation',
        state: FinancialReconciliationCheckState.notApplicable,
        detail: 'Affectation pas encore requise.',
      );
    }

    final bool linked = assignments.any(
      (ReconciliationAssignmentEvidence item) => item.agentId == agentId,
    );
    return FinancialReconciliationCheck(
      link: FinancialReconciliationLink.assignment,
      label: 'Affectation',
      state: linked
          ? FinancialReconciliationCheckState.coherent
          : FinancialReconciliationCheckState.attention,
      detail: linked
          ? 'Affectation historisée dans orderAssignments.'
          : 'Agent présent sur la commande mais aucune affectation correspondante n’a été retrouvée.',
    );
  }

  FinancialReconciliationCheck _agentCheck(
    QueueOrder order,
    FinancialReconciliationEvidence evidence,
  ) {
    final String? agentId = _clean(order.assignedAgentId);
    if (agentId == null) {
      return FinancialReconciliationCheck(
        link: FinancialReconciliationLink.agent,
        label: 'Agent',
        state: _requiresAgentLink(order)
            ? FinancialReconciliationCheckState.attention
            : FinancialReconciliationCheckState.notApplicable,
        detail: _requiresAgentLink(order)
            ? 'Aucun Agent relié à une commande déjà engagée dans le traitement.'
            : 'Agent pas encore requis.',
      );
    }
    final bool exists = evidence.agentUserIds.contains(agentId);
    return FinancialReconciliationCheck(
      link: FinancialReconciliationLink.agent,
      label: 'Agent',
      state: exists
          ? FinancialReconciliationCheckState.coherent
          : FinancialReconciliationCheckState.attention,
      detail: exists
          ? 'Compte Agent retrouvé.'
          : 'L’UID Agent de la commande ne correspond à aucun compte users existant.',
    );
  }

  FinancialReconciliationCheck _processingCheck(
    QueueOrder order,
    FinancialReconciliationEvidence evidence,
  ) {
    if (!_requiresProcessing(order)) {
      return const FinancialReconciliationCheck(
        link: FinancialReconciliationLink.processing,
        label: 'Traitement',
        state: FinancialReconciliationCheckState.notApplicable,
        detail: 'Traitement pas encore démarré.',
      );
    }

    final Set<String> events = evidence.eventsByOrder[order.id] ?? const <String>{};
    final bool hasStart = events.contains('PROCESSING_STARTED') || order.takenAt != null;
    final bool successPath = _isSuccessfulProcessingState(order);
    final bool failurePath = _isFailedProcessingPath(order);
    final bool hasResult = successPath
        ? events.contains('PROCESSING_SUCCEEDED') ||
            (order.completedAt != null && order.failureReason == null)
        : failurePath
            ? events.contains('PROCESSING_FAILED') || order.failureReason != null
            : true;

    if (hasStart && hasResult) {
      return const FinancialReconciliationCheck(
        link: FinancialReconciliationLink.processing,
        label: 'Traitement',
        state: FinancialReconciliationCheckState.coherent,
        detail: 'Démarrage et résultat du traitement cohérents.',
      );
    }

    final List<String> missing = <String>[
      if (!hasStart) 'démarrage',
      if (!hasResult) 'résultat',
    ];
    return FinancialReconciliationCheck(
      link: FinancialReconciliationLink.processing,
      label: 'Traitement',
      state: FinancialReconciliationCheckState.attention,
      detail: 'Trace de ${missing.join(' et ')} du traitement manquante.',
    );
  }

  FinancialReconciliationCheck _proofCheck(
    QueueOrder order,
    FinancialReconciliationEvidence evidence,
  ) {
    final bool requiresProof = _isSuccessfulProcessingState(order) &&
        _clean(order.assignedAgentId) != null;
    if (!requiresProof) {
      return const FinancialReconciliationCheck(
        link: FinancialReconciliationLink.proof,
        label: 'Preuve',
        state: FinancialReconciliationCheckState.notApplicable,
        detail: 'Preuve non exigée pour cet état.',
      );
    }
    final bool exists = evidence.proofOrderIds.contains(order.id);
    return FinancialReconciliationCheck(
      link: FinancialReconciliationLink.proof,
      label: 'Preuve',
      state: exists
          ? FinancialReconciliationCheckState.coherent
          : FinancialReconciliationCheckState.attention,
      detail: exists
          ? 'Preuve Agent retrouvée.'
          : 'Transaction réussie par un Agent sans preuve orderProofs liée.',
    );
  }

  FinancialReconciliationCheck _networkMovementCheck(
    QueueOrder order,
    FinancialReconciliationEvidence evidence,
  ) {
    final bool success = _isSuccessfulProcessingState(order) &&
        _clean(order.assignedAgentId) != null;
    if (!success) {
      return const FinancialReconciliationCheck(
        link: FinancialReconciliationLink.networkMovement,
        label: 'Mouvement réseau',
        state: FinancialReconciliationCheckState.notApplicable,
        detail: 'Aucune sortie réseau attendue pour cet état.',
      );
    }

    final DateTime? completedAt = order.completedAt;
    final DateTime? coverageStart = evidence.networkMovementCoverageStart;
    if (coverageStart != null &&
        completedAt != null &&
        completedAt.isBefore(coverageStart)) {
      return const FinancialReconciliationCheck(
        link: FinancialReconciliationLink.networkMovement,
        label: 'Mouvement réseau',
        state: FinancialReconciliationCheckState.notApplicable,
        detail: 'Commande antérieure à l’activation du journal réseau Phase 13.',
      );
    }

    final ReconciliationNetworkMovementEvidence? movement =
        evidence.networkMovementsByOrder[order.id];
    if (movement == null) {
      return FinancialReconciliationCheck(
        link: FinancialReconciliationLink.networkMovement,
        label: 'Mouvement réseau',
        state: coverageStart == null
            ? FinancialReconciliationCheckState.notApplicable
            : FinancialReconciliationCheckState.attention,
        detail: coverageStart == null
            ? 'Aucun mouvement Phase 13 disponible pour établir la période de contrôle.'
            : 'Commande réussie sans sortie networkTransactions correspondante.',
      );
    }

    final bool matches = movement.amount == order.amount &&
        movement.network == order.network.name &&
        movement.agentId == order.assignedAgentId;
    return FinancialReconciliationCheck(
      link: FinancialReconciliationLink.networkMovement,
      label: 'Mouvement réseau',
      state: matches
          ? FinancialReconciliationCheckState.coherent
          : FinancialReconciliationCheckState.attention,
      detail: matches
          ? 'Sortie réseau liée au bon montant, réseau et Agent.'
          : 'Le mouvement réseau ne correspond pas entièrement à la commande.',
    );
  }

  FinancialReconciliationCheck _commissionCheck(
    QueueOrder order,
    FinancialReconciliationEvidence evidence,
  ) {
    final bool success = _isSuccessfulProcessingState(order) &&
        _clean(order.assignedAgentId) != null;
    if (!success) {
      return const FinancialReconciliationCheck(
        link: FinancialReconciliationLink.commission,
        label: 'Commission',
        state: FinancialReconciliationCheckState.notApplicable,
        detail: 'Aucune commission attendue pour cet état.',
      );
    }

    final DateTime? completedAt = order.completedAt;
    final DateTime? coverageStart = evidence.commissionCoverageStart;
    if (coverageStart != null &&
        completedAt != null &&
        completedAt.isBefore(coverageStart)) {
      return const FinancialReconciliationCheck(
        link: FinancialReconciliationLink.commission,
        label: 'Commission',
        state: FinancialReconciliationCheckState.notApplicable,
        detail: 'Commande antérieure à l’activation des commissions Phase 12.',
      );
    }

    final ReconciliationCommissionEvidence? commission =
        evidence.commissionsByOrder[order.id];
    if (commission == null) {
      return FinancialReconciliationCheck(
        link: FinancialReconciliationLink.commission,
        label: 'Commission',
        state: coverageStart == null
            ? FinancialReconciliationCheckState.notApplicable
            : FinancialReconciliationCheckState.attention,
        detail: coverageStart == null
            ? 'Aucune commission disponible pour établir la période de contrôle.'
            : 'Commande réussie sans commission correspondante.',
      );
    }

    final bool matches = commission.agentId == order.assignedAgentId &&
        commission.orderAmount == order.amount &&
        commission.commissionAmount > 0;
    return FinancialReconciliationCheck(
      link: FinancialReconciliationLink.commission,
      label: 'Commission',
      state: matches
          ? FinancialReconciliationCheckState.coherent
          : FinancialReconciliationCheckState.attention,
      detail: matches
          ? 'Commission reliée au bon Agent et à la bonne commande.'
          : 'La commission ne correspond pas entièrement à la commande.',
    );
  }

  FinancialReconciliationCheck _refundCheck(
    QueueOrder order,
    ReconciliationRefundEvidence? refund,
  ) {
    final bool requiresRefund = order.status == QueueOrderStatus.refundPending ||
        order.status == QueueOrderStatus.refunded;
    if (refund == null) {
      return FinancialReconciliationCheck(
        link: FinancialReconciliationLink.refund,
        label: 'Remboursement',
        state: requiresRefund
            ? FinancialReconciliationCheckState.attention
            : FinancialReconciliationCheckState.notApplicable,
        detail: requiresRefund
            ? 'Statut de remboursement sans dossier refunds lié.'
            : 'Aucun remboursement attendu.',
      );
    }

    final bool amountValid = refund.amount > 0 && refund.amount <= order.amount;
    final bool statusValid = !requiresRefund ||
        (order.status == QueueOrderStatus.refundPending &&
            refund.status != 'rejected') ||
        (order.status == QueueOrderStatus.refunded &&
            (refund.status == 'refunded' || refund.status == 'reconciled'));
    final bool coherent = amountValid && statusValid;
    return FinancialReconciliationCheck(
      link: FinancialReconciliationLink.refund,
      label: 'Remboursement',
      state: coherent
          ? FinancialReconciliationCheckState.coherent
          : FinancialReconciliationCheckState.attention,
      detail: coherent
          ? refund.status == 'reconciled'
              ? 'Remboursement effectué et rapproché.'
              : 'Dossier de remboursement relié à la commande.'
          : 'Le montant ou le statut du remboursement n’est pas cohérent avec la commande.',
    );
  }

  bool _hasProgressedBeyondPayment(QueueOrder order) {
    return order.status == QueueOrderStatus.paidReady ||
        order.status == QueueOrderStatus.inProgress ||
        order.status == QueueOrderStatus.onHold ||
        order.status == QueueOrderStatus.awaitingCustomerConfirmation ||
        order.status == QueueOrderStatus.completed ||
        order.status == QueueOrderStatus.failed ||
        order.status == QueueOrderStatus.refundPending ||
        order.status == QueueOrderStatus.refunded;
  }

  bool _requiresAgentLink(QueueOrder order) {
    return order.status == QueueOrderStatus.inProgress ||
        order.status == QueueOrderStatus.onHold ||
        order.status == QueueOrderStatus.awaitingCustomerConfirmation ||
        order.status == QueueOrderStatus.completed ||
        order.status == QueueOrderStatus.failed ||
        order.status == QueueOrderStatus.refundPending ||
        order.status == QueueOrderStatus.refunded;
  }

  bool _requiresProcessing(QueueOrder order) => _requiresAgentLink(order);

  bool _isSuccessfulProcessingState(QueueOrder order) {
    if (order.status == QueueOrderStatus.awaitingCustomerConfirmation ||
        order.status == QueueOrderStatus.completed) {
      return order.failureReason == null;
    }
    if (order.status == QueueOrderStatus.refundPending ||
        order.status == QueueOrderStatus.refunded) {
      return order.failureReason == null;
    }
    return false;
  }

  bool _isFailedProcessingPath(QueueOrder order) {
    if (order.status == QueueOrderStatus.failed) return true;
    return (order.status == QueueOrderStatus.refundPending ||
            order.status == QueueOrderStatus.refunded) &&
        order.failureReason != null;
  }

  String? _clean(String? value) {
    final String cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }
}
