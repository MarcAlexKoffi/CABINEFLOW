import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
import 'package:cabine_flow/features/orders/domain/models/automatic_assignment.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Phase4AssignmentSnapshot {
  const Phase4AssignmentSnapshot({
    required this.orderId,
    required this.orderReference,
    required this.network,
    required this.amount,
    required this.source,
    required this.clientName,
    required this.clientWhatsappPhone,
    required this.beneficiaryPhone,
    required this.operationType,
    required this.offerLabel,
    required this.paymentStatus,
    required this.assignmentState,
    required this.firebaseCreatedAt,
    required this.updatedAt,
    this.originalWhatsappMessage,
    this.internalNotes,
    this.paymentPayerName,
    this.paymentReference,
    this.paymentConfirmedAt,
    this.paidAt,
    this.assignedAgentId,
    this.assignedAgentName,
    this.assignedByUid,
    this.assignmentMode,
    this.assignedAt,
    this.lastRefusalReason,
    this.lastRefusedAt,
    this.lastRefusedAgentId,
    this.firebaseAssignmentSyncedAt,
    this.firebaseHandoffAt,
    this.customerAuthUid,
    this.orderStatus = QueueOrderStatus.paidReady,
    this.processingStartedAt,
    this.completedAt,
    this.failureReason,
    this.observation,
    this.lastHoldReason,
    this.lastHeldAt,
    this.lastResumedAt,
    this.customerConfirmationStatus = CustomerConfirmationStatus.pending,
    this.customerConfirmationCompletedAt,
    this.legacyStateUnresolved = false,
  });

  final String orderId;
  final String orderReference;
  final MobileNetwork network;
  final int amount;
  final OrderSource source;
  final String clientName;
  final String clientWhatsappPhone;
  final String beneficiaryPhone;
  final OrderOperationType operationType;
  final String offerLabel;
  final String? originalWhatsappMessage;
  final String? internalNotes;
  final OrderPaymentStatus paymentStatus;
  final String? paymentPayerName;
  final String? paymentReference;
  final DateTime? paymentConfirmedAt;
  final String assignmentState;
  final DateTime firebaseCreatedAt;
  final DateTime? paidAt;
  final String? assignedAgentId;
  final String? assignedAgentName;
  final String? assignedByUid;
  final OrderAssignmentMode? assignmentMode;
  final DateTime? assignedAt;
  final String? lastRefusalReason;
  final DateTime? lastRefusedAt;
  final String? lastRefusedAgentId;
  final DateTime? firebaseAssignmentSyncedAt;
  final DateTime? firebaseHandoffAt;
  final String? customerAuthUid;
  final QueueOrderStatus orderStatus;
  final DateTime? processingStartedAt;
  final DateTime? completedAt;
  final OrderFailureReason? failureReason;
  final String? observation;
  final String? lastHoldReason;
  final DateTime? lastHeldAt;
  final DateTime? lastResumedAt;
  final CustomerConfirmationStatus customerConfirmationStatus;
  final DateTime? customerConfirmationCompletedAt;
  final bool legacyStateUnresolved;
  final DateTime updatedAt;

  bool get isAssigned => assignmentState == 'assigned';
  bool get isAccepted => assignmentState == 'accepted';
  bool get isHandedOff => assignmentState == 'handed_off';
  bool get isManualRequired => assignmentState == 'manual_required';
  bool get isWaiting => assignmentState == 'waiting';

  bool get reservesCapacityInSupabase {
    return !legacyStateUnresolved &&
        (assignmentState == 'assigned' || assignmentState == 'accepted') &&
        (orderStatus == QueueOrderStatus.paidReady ||
            orderStatus == QueueOrderStatus.inProgress ||
            orderStatus == QueueOrderStatus.onHold) &&
        assignedAgentId != null;
  }

  QueueOrder toQueueOrder({
    QueueOrder? legacy,
    List<String> refusedAgentIds = const <String>[],
  }) {
    final bool hasAssignment =
        assignedAgentId != null &&
        assignedAgentId!.trim().isNotEmpty &&
        !(isWaiting || isManualRequired);
    final OrderAssignmentStatus assignmentStatus = !hasAssignment
        ? OrderAssignmentStatus.unassigned
        : isAssigned
        ? OrderAssignmentStatus.assigned
        : OrderAssignmentStatus.accepted;

    return QueueOrder(
      id: orderId,
      reference: orderReference,
      source: source,
      customerAuthUid: customerAuthUid ?? legacy?.customerAuthUid,
      clientName: clientName,
      clientWhatsappPhone: clientWhatsappPhone,
      network: network,
      beneficiaryPhone: beneficiaryPhone,
      operationType: operationType,
      offerLabel: offerLabel,
      amount: amount,
      originalWhatsappMessage:
          originalWhatsappMessage ?? legacy?.originalWhatsappMessage,
      internalNotes: internalNotes ?? legacy?.internalNotes,
      createdAt: firebaseCreatedAt,
      paidAt: paidAt ?? legacy?.paidAt,
      paymentRequestSentAt: legacy?.paymentRequestSentAt,
      paymentDeclaredAt: legacy?.paymentDeclaredAt,
      paymentPayerName: paymentPayerName ?? legacy?.paymentPayerName,
      paymentPayerPhone: legacy?.paymentPayerPhone,
      paymentApproximateTime: legacy?.paymentApproximateTime,
      paymentDeclaredReference: legacy?.paymentDeclaredReference,
      paymentConfirmedAt: paymentConfirmedAt ?? legacy?.paymentConfirmedAt,
      expiresAt: legacy?.expiresAt,
      expiredAt: legacy?.expiredAt,
      paymentReference: paymentReference ?? legacy?.paymentReference,
      status: orderStatus,
      paymentStatus: paymentStatus,
      takenByUserId: processingStartedAt == null ? null : assignedAgentId,
      takenAt: processingStartedAt,
      completedAt: completedAt,
      failureReason: failureReason,
      observation: observation,
      customerConfirmationStatus: customerConfirmationStatus,
      customerConfirmationCompletedAt: customerConfirmationCompletedAt,
      assignedAgentId: hasAssignment ? assignedAgentId : null,
      assignedAgentName: hasAssignment ? assignedAgentName : null,
      assignedByUserId: hasAssignment ? assignedByUid : null,
      assignedAt: hasAssignment ? assignedAt : null,
      assignmentMode: hasAssignment ? assignmentMode : null,
      assignmentStatus: assignmentStatus,
      lastAssignmentRefusalReason: lastRefusalReason,
      lastAssignmentRefusedAt: lastRefusedAt,
      lastAssignmentRefusedAgentId: lastRefusedAgentId,
      autoAssignmentRefusedAgentIds: refusedAgentIds,
      manualAssignmentRequired: isManualRequired,
      lastHoldReason: lastHoldReason,
      lastHeldAt: lastHeldAt,
      lastResumedAt: lastResumedAt,
    );
  }

  QueueOrder toPendingQueueOrder({
    List<String> refusedAgentIds = const <String>[],
  }) => toQueueOrder(refusedAgentIds: refusedAgentIds);

  QueueOrder overlayOn(
    QueueOrder order, {
    List<String> refusedAgentIds = const <String>[],
  }) {
    // Une ligne Supabase synchronisee est canonique pour le statut operationnel.
    // Firestore ne sert plus ici que de source de champs historiques non migres.
    return toQueueOrder(
      legacy: order,
      refusedAgentIds: refusedAgentIds,
    );
  }

}


class Phase4AgentActionOutcome {
  const Phase4AgentActionOutcome({
    required this.action,
    required this.assignmentState,
    required this.reassigned,
    required this.manualRequired,
  });

  final String action;
  final String assignmentState;
  final bool reassigned;
  final bool manualRequired;

  bool get isAccepted =>
      action == 'accept' && assignmentState == 'accepted';

  bool get isRefusalApplied =>
      action == 'refuse' &&
      (reassigned || manualRequired || assignmentState == 'waiting');
}

class Phase4AssignmentPlan {
  const Phase4AssignmentPlan({
    required this.orderId,
    required this.candidateAgentIds,
    required this.refusedAgentIds,
    required this.mode,
  });

  final String orderId;
  final List<String> candidateAgentIds;
  final List<String> refusedAgentIds;
  final OrderAssignmentMode mode;
}

class Phase4RefusalHistorySnapshot {
  const Phase4RefusalHistorySnapshot({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.agentId,
    required this.agentName,
    required this.assignedAt,
    required this.refusedAt,
    required this.refusalReason,
  });

  final String id;
  final String orderId;
  final String orderReference;
  final String agentId;
  final String agentName;
  final DateTime? assignedAt;
  final DateTime? refusedAt;
  final String? refusalReason;
}

class Phase4AssignmentHistorySnapshot {
  const Phase4AssignmentHistorySnapshot({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.agentId,
    required this.agentName,
    required this.status,
    required this.assignedAt,
    this.acceptedAt,
    this.refusedAt,
    this.refusalReason,
  });

  final String id;
  final String orderId;
  final String orderReference;
  final String agentId;
  final String agentName;
  final String status;
  final DateTime? assignedAt;
  final DateTime? acceptedAt;
  final DateTime? refusedAt;
  final String? refusalReason;
}

class Phase4AgentAssignmentState {
  const Phase4AgentAssignmentState({
    required this.currentAssignments,
    required this.knownPhase4OrderIds,
  });

  final List<Phase4AssignmentSnapshot> currentAssignments;
  final Set<String> knownPhase4OrderIds;
}

class SupabasePhase4AssignmentRepository {
  SupabasePhase4AssignmentRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String ordersTable = 'phase4_assignment_orders';
  static const String plansTable = 'phase4_assignment_plans';
  static const String historyTable = 'phase4_assignment_history';
  static const Duration pollInterval = Duration(seconds: 3);

  final SupabaseClient _client;

  Future<Phase4AssignmentSnapshot> syncOrder(QueueOrder order) async {
    if (!order.isFundedForProcessing ||
        order.status != QueueOrderStatus.paidReady) {
      throw StateError(
        'Seules les commandes financées et prêtes peuvent être synchronisées.',
      );
    }

    final Object? raw = await _client.rpc(
      'phase3_sync_order',
      params: <String, dynamic>{
        'p_order_id': order.id,
        'p_order_reference': order.reference,
        'p_network': order.network.name,
        'p_amount': order.amount,
        'p_firebase_created_at': order.createdAt.toUtc().toIso8601String(),
        'p_paid_at': order.paidAt?.toUtc().toIso8601String(),
        'p_source': order.source.name,
        'p_client_name': order.clientName,
        'p_client_whatsapp_phone': order.clientWhatsappPhone,
        'p_beneficiary_phone': order.beneficiaryPhone,
        'p_operation_type': order.operationType.name,
        'p_offer_label': order.offerLabel,
        'p_original_whatsapp_message': order.originalWhatsappMessage,
        'p_internal_notes': order.internalNotes,
        'p_payment_status': order.paymentStatus.name,
        'p_payment_payer_name': order.paymentPayerName,
        'p_payment_reference': order.paymentReference,
        'p_payment_confirmed_at': order.paymentConfirmedAt
            ?.toUtc()
            .toIso8601String(),
        'p_customer_auth_uid': order.customerAuthUid,
      },
    );
    return _requireSnapshot(raw);
  }

  Future<Phase4AssignmentSnapshot> assignRanked({
    required String orderId,
    required List<AutomaticAssignmentAgent> candidates,
    required OrderAssignmentMode mode,
  }) async {
    final List<String> ids = candidates
        .map((AutomaticAssignmentAgent item) => item.agentId.trim())
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);
    final Map<String, String> names = <String, String>{
      for (final AutomaticAssignmentAgent item in candidates)
        if (item.agentId.trim().isNotEmpty)
          item.agentId.trim(): item.name.trim().isEmpty
              ? 'Agent'
              : item.name.trim(),
    };

    final Object? raw = await _client.rpc(
      'phase4_assign_ranked',
      params: <String, dynamic>{
        'p_order_id': orderId.trim(),
        'p_candidate_agent_ids': ids,
        'p_candidate_names': names,
        'p_mode': mode.name,
      },
    );
    return _requireSnapshot(raw);
  }

  Future<Phase4AgentActionOutcome> accept(String orderId) async {
    final Phase4AgentActionOutcome outcome = await _agentAction(
      orderId: orderId,
      action: 'accept',
    );
    if (!outcome.isAccepted) {
      throw StateError(
        'L’acceptation n’a pas pu être confirmée. Actualise la file puis réessaie.',
      );
    }
    return outcome;
  }

  Future<Phase4AgentActionOutcome> refuse({
    required String orderId,
    required String reason,
  }) async {
    final Phase4AgentActionOutcome outcome = await _agentAction(
      orderId: orderId,
      action: 'refuse',
      reason: reason.trim(),
    );

    // Apres un refus, la RLS retire immediatement a l'ancien Agent le droit de
    // relire phase4_assignment_orders. L'issue de la transition doit donc etre
    // retournee par le RPC atomique, et non confirmee par un SELECT devenu
    // volontairement invisible pour l'Agent qui vient de refuser.
    if (!outcome.isRefusalApplied) {
      throw StateError(
        'Le refus n’a pas pu être confirmé. Actualise la file puis réessaie.',
      );
    }
    return outcome;
  }

  Future<Phase4AgentActionOutcome> _agentAction({
    required String orderId,
    required String action,
    String? reason,
  }) async {
    final Object? raw = await _client.rpc(
      'phase4_agent_action',
      params: <String, dynamic>{
        'p_order_id': orderId.trim(),
        'p_action': action,
        'p_reason': reason,
      },
    );
    final Map<String, dynamic>? result = raw is Map<String, dynamic>
        ? raw
        : raw is Map
        ? Map<String, dynamic>.from(raw)
        : null;
    if (result == null || result['ok'] != true) {
      throw StateError('Impossible de confirmer cette action pour le moment.');
    }

    final String returnedAction = _string(result['action']);
    final String assignmentState = _string(result['assignment_state']);
    if (returnedAction != action || assignmentState.isEmpty) {
      throw StateError('Impossible de confirmer cette action pour le moment.');
    }

    return Phase4AgentActionOutcome(
      action: returnedAction,
      assignmentState: assignmentState,
      reassigned: result['reassigned'] == true,
      manualRequired: result['manual_required'] == true,
    );
  }

  Future<Phase4AssignmentSnapshot> markFirebaseAssignmentSynced(
    String orderId,
  ) async {
    final Object? raw = await _client.rpc(
      'phase4_mark_assignment_synced',
      params: <String, dynamic>{'p_order_id': orderId.trim()},
    );
    return _requireSnapshot(raw);
  }

  Future<Phase4AssignmentSnapshot> markHandoff(String orderId) async {
    final Object? raw = await _client.rpc(
      'phase4_mark_handoff',
      params: <String, dynamic>{'p_order_id': orderId.trim()},
    );
    return _requireSnapshot(raw);
  }

  Future<Phase4AssignmentSnapshot> reopenAcceptance(String orderId) async {
    final Object? raw = await _client.rpc(
      'phase4_reopen_acceptance',
      params: <String, dynamic>{'p_order_id': orderId.trim()},
    );
    return _requireSnapshot(raw);
  }

  Future<Phase4AssignmentSnapshot> reconcileAcceptance({
    required String orderId,
    required bool firebaseHandoffConfirmed,
  }) async {
    final Object? raw = await _client.rpc(
      'phase4_reconcile_acceptance',
      params: <String, dynamic>{
        'p_order_id': orderId.trim(),
        'p_firebase_handoff_confirmed': firebaseHandoffConfirmed,
      },
    );
    return _requireSnapshot(raw);
  }

  Future<Phase4AssignmentSnapshot> resetForManualAssignment(
    String orderId,
  ) async {
    final Object? raw = await _client.rpc(
      'phase4_reset_for_manual_assignment',
      params: <String, dynamic>{'p_order_id': orderId.trim()},
    );
    return _requireSnapshot(raw);
  }


  Future<bool> isAgentEligibleForOrder({
    required String agentId,
    required String orderId,
  }) async {
    final Object? raw = await _client.rpc(
      'phase3_agent_is_eligible_for_order',
      params: <String, dynamic>{
        'p_agent_id': agentId.trim(),
        'p_order_id': orderId.trim(),
      },
    );
    if (raw is bool) return raw;
    throw StateError('Reponse d eligibilite Supabase invalide.');
  }

  Future<List<AutomaticAssignmentAgent>> fetchAssignmentCandidates() async {
    final Object? raw = await _client.rpc('phase3_assignment_candidates');
    final List<dynamic> rows = raw is List ? raw : const <dynamic>[];
    return List<AutomaticAssignmentAgent>.unmodifiable(
      rows
          .whereType<Map>()
          .map((Map row) => _assignmentCandidateFromRow(
                Map<String, dynamic>.from(row),
              ))
          .whereType<AutomaticAssignmentAgent>(),
    );
  }

  Future<Phase4AssignmentSnapshot> startProcessing(String orderId) {
    return _processingAction(orderId: orderId, action: 'start');
  }

  Future<Phase4AssignmentSnapshot> holdProcessing({
    required String orderId,
    required String reason,
  }) {
    return _processingAction(
      orderId: orderId,
      action: 'hold',
      reason: reason.trim(),
    );
  }

  Future<Phase4AssignmentSnapshot> resumeProcessing(String orderId) {
    return _processingAction(orderId: orderId, action: 'resume');
  }

  Future<Phase4AssignmentSnapshot> failProcessing({
    required String orderId,
    required OrderFailureReason reason,
    String? observation,
  }) {
    return _processingAction(
      orderId: orderId,
      action: 'fail',
      reason: reason.name,
      observation: observation?.trim(),
    );
  }

  Future<Phase4AssignmentSnapshot> _processingAction({
    required String orderId,
    required String action,
    String? reason,
    String? observation,
  }) async {
    final Object? raw = await _client.rpc(
      'phase3_agent_processing_action',
      params: <String, dynamic>{
        'p_order_id': orderId.trim(),
        'p_action': action,
        'p_reason': reason,
        'p_observation': observation,
      },
    );
    return _requireSnapshot(raw);
  }

  Future<Phase4AssignmentSnapshot> prepareFailedForReassignment(
    String orderId,
  ) async {
    final Object? raw = await _client.rpc(
      'phase3_prepare_failed_order_for_reassignment',
      params: <String, dynamic>{'p_order_id': orderId.trim()},
    );
    return _requireSnapshot(raw);
  }

  Future<Phase4AssignmentSnapshot> importLegacyRefusals({
    required String orderId,
    required List<String> refusedAgentIds,
    required bool manualRequired,
  }) async {
    final Object? raw = await _client.rpc(
      'phase4_import_legacy_refusals',
      params: <String, dynamic>{
        'p_order_id': orderId.trim(),
        'p_refused_agent_ids': refusedAgentIds,
        'p_manual_required': manualRequired,
      },
    );
    return _requireSnapshot(raw);
  }

  Future<Phase4AssignmentSnapshot> closeOrder(String orderId) async {
    final Object? raw = await _client.rpc(
      'phase4_close_order',
      params: <String, dynamic>{'p_order_id': orderId.trim()},
    );
    return _requireSnapshot(raw);
  }

  Future<Phase4AssignmentSnapshot?> fetchOrder(String orderId) async {
    final String id = orderId.trim();
    if (id.isEmpty) return null;
    final List<Map<String, dynamic>> rows = await _client
        .from(ordersTable)
        .select()
        .eq('order_id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    return _snapshotFromRow(rows.first);
  }

  Future<List<Phase4AssignmentSnapshot>> fetchAllForStaff() async {
    final List<Map<String, dynamic>> rows = await _client
        .from(ordersTable)
        .select();
    return _snapshotsFromRows(rows);
  }

  Stream<List<Phase4AssignmentSnapshot>> watchAllForStaff() async* {
    List<Phase4AssignmentSnapshot>? lastSuccessful;
    int consecutiveFailures = 0;
    while (true) {
      try {
        final List<Phase4AssignmentSnapshot> value = await fetchAllForStaff();
        lastSuccessful = value;
        consecutiveFailures = 0;
        yield value;
      } catch (error, stackTrace) {
        // Une coupure reseau ou un jeton Supabase momentanement indisponible ne
        // doit jamais tuer le flux pour toute la session. Sans ce retry, les
        // ecrans Admin restaient ensuite en mode Firebase-only meme lorsque
        // Supabase redevenait joignable, d'ou les statuts d'affectation qui
        // semblaient revenir en arriere.
        IzyTelLog.backendError(
          'Phase4Assignment.staff-watch',
          error,
          stackTrace: stackTrace,
        );
        if (!BackendFailurePolicy.canRetryRead(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        consecutiveFailures += 1;
        yield lastSuccessful ?? const <Phase4AssignmentSnapshot>[];
      }
      await Future<void>.delayed(
        BackendFailurePolicy.retryDelay(
          baseDelay: pollInterval,
          consecutiveFailures: consecutiveFailures,
        ),
      );
    }
  }

  Future<List<Phase4AssignmentSnapshot>> fetchAgentAssignments(
    String agentId,
  ) async {
    final String id = agentId.trim();
    if (id.isEmpty) return const <Phase4AssignmentSnapshot>[];
    final List<Map<String, dynamic>> rows = await _client
        .from(ordersTable)
        .select()
        .eq('assigned_agent_id', id);
    final List<Phase4AssignmentSnapshot> snapshots = _snapshotsFromRows(rows)
        .where(
          (Phase4AssignmentSnapshot item) =>
              item.assignmentState == 'assigned' ||
              item.assignmentState == 'accepted' ||
              item.assignmentState == 'handed_off',
        )
        .toList(growable: false);
    return List<Phase4AssignmentSnapshot>.unmodifiable(snapshots);
  }

  Future<Phase4AgentAssignmentState> fetchAgentAssignmentState(
    String agentId,
  ) async {
    final String id = agentId.trim();
    if (id.isEmpty) {
      return const Phase4AgentAssignmentState(
        currentAssignments: <Phase4AssignmentSnapshot>[],
        knownPhase4OrderIds: <String>{},
      );
    }

    final List<Phase4AssignmentSnapshot> current = await fetchAgentAssignments(
      id,
    );
    final List<Map<String, dynamic>> historyRows = await _client
        .from(historyTable)
        .select('order_id')
        .eq('agent_id', id);
    final Set<String> knownIds = historyRows
        .map((Map<String, dynamic> row) => _string(row['order_id']))
        .where((String orderId) => orderId.isNotEmpty)
        .toSet();

    return Phase4AgentAssignmentState(
      currentAssignments: current,
      knownPhase4OrderIds: Set<String>.unmodifiable(knownIds),
    );
  }

  Stream<Phase4AgentAssignmentState> watchAgentAssignmentState(
    String agentId,
  ) async* {
    Phase4AgentAssignmentState? lastSuccessful;
    int consecutiveFailures = 0;
    while (true) {
      try {
        final Phase4AgentAssignmentState value =
            await fetchAgentAssignmentState(agentId);
        lastSuccessful = value;
        consecutiveFailures = 0;
        yield value;
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'Phase4Assignment.agent-watch',
          error,
          stackTrace: stackTrace,
        );
        if (!BackendFailurePolicy.canRetryRead(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        consecutiveFailures += 1;
        yield lastSuccessful ?? const Phase4AgentAssignmentState(
          currentAssignments: <Phase4AssignmentSnapshot>[],
          knownPhase4OrderIds: <String>{},
        );
      }
      await Future<void>.delayed(
        BackendFailurePolicy.retryDelay(
          baseDelay: pollInterval,
          consecutiveFailures: consecutiveFailures,
        ),
      );
    }
  }

  Stream<List<Phase4AssignmentSnapshot>> watchAgentAssignments(String agentId) {
    return watchAgentAssignmentState(
      agentId,
    ).map((Phase4AgentAssignmentState value) => value.currentAssignments);
  }

  Future<List<Phase4AssignmentHistorySnapshot>> fetchAgentAssignmentHistory(
    String agentId,
  ) async {
    final String id = agentId.trim();
    if (id.isEmpty) return const <Phase4AssignmentHistorySnapshot>[];
    final List<Map<String, dynamic>> rows = await _client
        .from(historyTable)
        .select()
        .eq('agent_id', id)
        .order('assigned_at', ascending: false);
    return rows
        .map(_assignmentHistoryFromRow)
        .whereType<Phase4AssignmentHistorySnapshot>()
        .toList(growable: false);
  }

  Stream<List<Phase4AssignmentHistorySnapshot>> watchAgentAssignmentHistory(
    String agentId,
  ) async* {
    List<Phase4AssignmentHistorySnapshot>? lastSuccessful;
    int consecutiveFailures = 0;
    while (true) {
      try {
        final List<Phase4AssignmentHistorySnapshot> value =
            await fetchAgentAssignmentHistory(agentId);
        lastSuccessful = value;
        consecutiveFailures = 0;
        yield value;
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'Phase4Assignment.agent-history',
          error,
          stackTrace: stackTrace,
        );
        if (!BackendFailurePolicy.canRetryRead(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        consecutiveFailures += 1;
        yield lastSuccessful ?? const <Phase4AssignmentHistorySnapshot>[];
      }
      await Future<void>.delayed(
        BackendFailurePolicy.retryDelay(
          baseDelay: pollInterval,
          consecutiveFailures: consecutiveFailures,
        ),
      );
    }
  }

  Future<List<Phase4RefusalHistorySnapshot>> fetchAgentRefusalHistory(
    String agentId,
  ) async {
    final String id = agentId.trim();
    if (id.isEmpty) return const <Phase4RefusalHistorySnapshot>[];
    final List<Map<String, dynamic>> rows = await _client
        .from(historyTable)
        .select()
        .eq('agent_id', id)
        .eq('status', 'refused')
        .order('refused_at', ascending: false);
    return rows
        .map(_refusalHistoryFromRow)
        .whereType<Phase4RefusalHistorySnapshot>()
        .toList(growable: false);
  }

  Stream<List<Phase4RefusalHistorySnapshot>> watchAgentRefusalHistory(
    String agentId,
  ) async* {
    List<Phase4RefusalHistorySnapshot>? lastSuccessful;
    int consecutiveFailures = 0;
    while (true) {
      try {
        final List<Phase4RefusalHistorySnapshot> value =
            await fetchAgentRefusalHistory(agentId);
        lastSuccessful = value;
        consecutiveFailures = 0;
        yield value;
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'Phase4Assignment.refusal-history',
          error,
          stackTrace: stackTrace,
        );
        if (!BackendFailurePolicy.canRetryRead(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        consecutiveFailures += 1;
        yield lastSuccessful ?? const <Phase4RefusalHistorySnapshot>[];
      }
      await Future<void>.delayed(
        BackendFailurePolicy.retryDelay(
          baseDelay: pollInterval,
          consecutiveFailures: consecutiveFailures,
        ),
      );
    }
  }

  Future<List<QueueOrder>> fetchAgentRefusedOrders(String agentId) async {
    final String id = agentId.trim();
    if (id.isEmpty) return const <QueueOrder>[];
    final List<Map<String, dynamic>> rows = await _client
        .from(historyTable)
        .select()
        .eq('agent_id', id)
        .eq('status', 'refused')
        .order('refused_at', ascending: false);
    return rows
        .map(_refusedOrderFromHistoryRow)
        .whereType<QueueOrder>()
        .toList(growable: false);
  }

  Stream<List<QueueOrder>> watchAgentRefusedOrders(String agentId) async* {
    List<QueueOrder>? lastSuccessful;
    int consecutiveFailures = 0;
    while (true) {
      try {
        final List<QueueOrder> value = await fetchAgentRefusedOrders(agentId);
        lastSuccessful = value;
        consecutiveFailures = 0;
        yield value;
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'Phase4Assignment.refused-orders',
          error,
          stackTrace: stackTrace,
        );
        if (!BackendFailurePolicy.canRetryRead(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        consecutiveFailures += 1;
        yield lastSuccessful ?? const <QueueOrder>[];
      }
      await Future<void>.delayed(
        BackendFailurePolicy.retryDelay(
          baseDelay: pollInterval,
          consecutiveFailures: consecutiveFailures,
        ),
      );
    }
  }

  Future<Phase4AssignmentPlan?> fetchPlan(String orderId) async {
    final String id = orderId.trim();
    if (id.isEmpty) return null;
    final List<Map<String, dynamic>> rows = await _client
        .from(plansTable)
        .select()
        .eq('order_id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    final Map<String, dynamic> row = rows.first;
    return Phase4AssignmentPlan(
      orderId: id,
      candidateAgentIds: _stringList(row['candidate_agent_ids']),
      refusedAgentIds: _stringList(row['refused_agent_ids']),
      mode: _assignmentMode(row['plan_mode']) ?? OrderAssignmentMode.automatic,
    );
  }

  List<Phase4AssignmentSnapshot> _snapshotsFromRows(
    List<Map<String, dynamic>> rows,
  ) {
    final List<Phase4AssignmentSnapshot> result =
        rows
            .map(_snapshotFromRow)
            .whereType<Phase4AssignmentSnapshot>()
            .toList(growable: false)
          ..sort((Phase4AssignmentSnapshot a, Phase4AssignmentSnapshot b) {
            final DateTime aDate =
                a.assignedAt ?? a.paidAt ?? a.firebaseCreatedAt;
            final DateTime bDate =
                b.assignedAt ?? b.paidAt ?? b.firebaseCreatedAt;
            return bDate.compareTo(aDate);
          });
    return List<Phase4AssignmentSnapshot>.unmodifiable(result);
  }

  Phase4AssignmentSnapshot _requireSnapshot(Object? raw) {
    final Map<String, dynamic>? row = _rowFromRpc(raw);
    final Phase4AssignmentSnapshot? snapshot = row == null
        ? null
        : _snapshotFromRow(row);
    if (snapshot == null) {
      throw StateError('Réponse Supabase Phase 4 invalide.');
    }
    return snapshot;
  }

  Map<String, dynamic>? _rowFromRpc(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty) {
      final Object? first = raw.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  Phase4AssignmentSnapshot? _snapshotFromRow(Map<String, dynamic> row) {
    final String orderId = _string(row['order_id']);
    final String reference = _string(row['order_reference']);
    final MobileNetwork? network = _network(row['network']);
    final int amount = _int(row['amount']);
    final DateTime? createdAt = _date(row['firebase_created_at']);
    final DateTime? updatedAt = _date(row['updated_at']);
    final String state = _string(row['assignment_state']);
    final OrderSource? source = _enumByName(OrderSource.values, row['source']);
    final OrderOperationType? operationType = _enumByName(
      OrderOperationType.values,
      row['operation_type'],
    );
    final OrderPaymentStatus? paymentStatus = _enumByName(
      OrderPaymentStatus.values,
      row['payment_status'],
    );
    if (orderId.isEmpty ||
        reference.isEmpty ||
        network == null ||
        amount <= 0 ||
        createdAt == null ||
        updatedAt == null ||
        state.isEmpty ||
        source == null ||
        operationType == null ||
        paymentStatus == null) {
      return null;
    }

    return Phase4AssignmentSnapshot(
      orderId: orderId,
      orderReference: reference,
      network: network,
      amount: amount,
      source: source,
      clientName: _string(row['client_name'], fallback: 'Client'),
      clientWhatsappPhone: _string(row['client_whatsapp_phone']),
      beneficiaryPhone: _string(row['beneficiary_phone']),
      operationType: operationType,
      offerLabel: _string(row['offer_label'], fallback: 'Offre non renseignée'),
      originalWhatsappMessage: _nullable(row['original_whatsapp_message']),
      internalNotes: _nullable(row['internal_notes']),
      paymentStatus: paymentStatus,
      paymentPayerName: _nullable(row['payment_payer_name']),
      paymentReference: _nullable(row['payment_reference']),
      paymentConfirmedAt: _date(row['payment_confirmed_at']),
      assignmentState: state,
      firebaseCreatedAt: createdAt,
      paidAt: _date(row['paid_at']),
      assignedAgentId: _nullable(row['assigned_agent_id']),
      assignedAgentName: _nullable(row['assigned_agent_name']),
      assignedByUid: _nullable(row['assigned_by_uid']),
      assignmentMode: _assignmentMode(row['assignment_mode']),
      assignedAt: _date(row['assigned_at']),
      lastRefusalReason: _nullable(row['last_refusal_reason']),
      lastRefusedAt: _date(row['last_refused_at']),
      lastRefusedAgentId: _nullable(row['last_refused_agent_id']),
      firebaseAssignmentSyncedAt: _date(row['firebase_assignment_synced_at']),
      firebaseHandoffAt: _date(row['firebase_handoff_at']),
      customerAuthUid: _nullable(row['customer_auth_uid']),
      orderStatus:
          _enumByName(QueueOrderStatus.values, row['order_status']) ??
          QueueOrderStatus.paidReady,
      processingStartedAt: _date(row['processing_started_at']),
      completedAt: _date(row['completed_at']),
      failureReason: _enumByName(
        OrderFailureReason.values,
        row['failure_reason'],
      ),
      observation: _nullable(row['observation']),
      lastHoldReason: _nullable(row['last_hold_reason']),
      lastHeldAt: _date(row['last_held_at']),
      lastResumedAt: _date(row['last_resumed_at']),
      customerConfirmationStatus:
          _enumByName(
            CustomerConfirmationStatus.values,
            row['customer_confirmation_status'],
          ) ??
          CustomerConfirmationStatus.pending,
      customerConfirmationCompletedAt: _date(
        row['customer_confirmation_completed_at'],
      ),
      legacyStateUnresolved: row['legacy_state_unresolved'] == true,
      updatedAt: updatedAt,
    );
  }

  AutomaticAssignmentAgent? _assignmentCandidateFromRow(
    Map<String, dynamic> row,
  ) {
    final String agentId = _string(row['agent_id']);
    if (agentId.isEmpty) return null;
    return AutomaticAssignmentAgent(
      agentId: agentId,
      name: _string(row['agent_name'], fallback: 'Agent'),
      isActive: row['is_active'] == true,
      isAvailable: row['is_available'] == true,
      authorizedNetworks: _networkSet(row['authorized_networks']),
      activeNetworks: _networkSet(row['active_networks']),
      orangeCapacity: _int(row['orange_capacity']),
      mtnCapacity: _int(row['mtn_capacity']),
      moovCapacity: _int(row['moov_capacity']),
      dailyTransactionLimit: _int(row['daily_transaction_limit']),
      maxTransactionsPerDay: _int(row['max_transactions_per_day']),
      activeAssignmentCount: _int(row['active_assignment_count']),
      orangeReservedAmount: _int(row['orange_reserved_amount']),
      mtnReservedAmount: _int(row['mtn_reserved_amount']),
      moovReservedAmount: _int(row['moov_reserved_amount']),
      todayAssignmentCount: _int(row['today_assignment_count']),
      todayAssignedAmount: _int(row['today_assigned_amount']),
      lastAssignedAt: _date(row['last_assigned_at']),
    );
  }

  Set<MobileNetwork> _networkSet(Object? raw) {
    if (raw is! List) return const <MobileNetwork>{};
    return raw
        .map(_network)
        .whereType<MobileNetwork>()
        .toSet();
  }

  Phase4AssignmentHistorySnapshot? _assignmentHistoryFromRow(
    Map<String, dynamic> row,
  ) {
    final String id = _string(row['id']);
    final String orderId = _string(row['order_id']);
    final String reference = _string(row['order_reference']);
    final String agentId = _string(row['agent_id']);
    final String status = _string(row['status']);
    if (id.isEmpty || orderId.isEmpty || reference.isEmpty ||
        agentId.isEmpty || status.isEmpty) {
      return null;
    }
    return Phase4AssignmentHistorySnapshot(
      id: id,
      orderId: orderId,
      orderReference: reference,
      agentId: agentId,
      agentName: _string(row['agent_name'], fallback: 'Agent'),
      status: status,
      assignedAt: _date(row['assigned_at']),
      acceptedAt: _date(row['accepted_at']),
      refusedAt: _date(row['refused_at']),
      refusalReason: _nullable(row['refusal_reason']),
    );
  }

  Phase4RefusalHistorySnapshot? _refusalHistoryFromRow(
    Map<String, dynamic> row,
  ) {
    final String id = _string(row['id']);
    final String orderId = _string(row['order_id']);
    final String reference = _string(row['order_reference']);
    final String agentId = _string(row['agent_id']);
    if (id.isEmpty || orderId.isEmpty || reference.isEmpty || agentId.isEmpty) {
      return null;
    }
    return Phase4RefusalHistorySnapshot(
      id: id,
      orderId: orderId,
      orderReference: reference,
      agentId: agentId,
      agentName: _string(row['agent_name'], fallback: 'Agent'),
      assignedAt: _date(row['assigned_at']),
      refusedAt: _date(row['refused_at']),
      refusalReason: _nullable(row['refusal_reason']),
    );
  }

  QueueOrder? _refusedOrderFromHistoryRow(Map<String, dynamic> row) {
    final String orderId = _string(row['order_id']);
    final String reference = _string(row['order_reference']);
    final String agentId = _string(row['agent_id']);
    final MobileNetwork? network = _network(row['network']);
    final int amount = _int(row['amount']);
    final DateTime? createdAt = _date(row['firebase_created_at']);
    final DateTime? refusedAt = _date(row['refused_at']);
    final OrderSource? source = _enumByName(OrderSource.values, row['source']);
    final OrderOperationType? operationType = _enumByName(
      OrderOperationType.values,
      row['operation_type'],
    );
    final OrderPaymentStatus? paymentStatus = _enumByName(
      OrderPaymentStatus.values,
      row['payment_status'],
    );
    if (orderId.isEmpty ||
        reference.isEmpty ||
        agentId.isEmpty ||
        network == null ||
        amount <= 0 ||
        createdAt == null ||
        source == null ||
        operationType == null ||
        paymentStatus == null) {
      return null;
    }
    final String reason = _string(
      row['refusal_reason'],
      fallback: 'Motif non renseigné',
    );
    return QueueOrder(
      id: orderId,
      reference: reference,
      source: source,
      clientName: _string(row['client_name'], fallback: 'Client'),
      clientWhatsappPhone: '',
      network: network,
      beneficiaryPhone: _string(row['beneficiary_phone']),
      operationType: operationType,
      offerLabel: _string(row['offer_label'], fallback: 'Offre non renseignée'),
      amount: amount,
      createdAt: createdAt,
      paidAt: _date(row['paid_at']),
      status: QueueOrderStatus.paidReady,
      paymentStatus: paymentStatus,
      assignedAgentId: agentId,
      assignedAgentName: _string(row['agent_name'], fallback: 'Agent'),
      assignedAt: _date(row['assigned_at']),
      assignmentMode: _assignmentMode(row['mode']),
      assignmentStatus: OrderAssignmentStatus.refused,
      lastAssignmentRefusalReason: reason,
      lastAssignmentRefusedAt: refusedAt,
      lastAssignmentRefusedAgentId: agentId,
      autoAssignmentRefusedAgentIds: <String>[agentId],
    );
  }

  MobileNetwork? _network(Object? raw) {
    final String value = _string(raw).toLowerCase();
    for (final MobileNetwork network in MobileNetwork.values) {
      if (network.name == value) return network;
    }
    return null;
  }

  T? _enumByName<T extends Enum>(List<T> values, Object? raw) {
    final String value = _string(raw);
    for (final T item in values) {
      if (item.name == value) return item;
    }
    return null;
  }

  OrderAssignmentMode? _assignmentMode(Object? raw) {
    return _enumByName(OrderAssignmentMode.values, raw);
  }

  List<String> _stringList(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw
        .whereType<String>()
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _string(Object? raw, {String fallback = ''}) {
    if (raw is! String || raw.trim().isEmpty) return fallback;
    return raw.trim();
  }

  String? _nullable(Object? raw) {
    final String value = _string(raw);
    return value.isEmpty ? null : value;
  }

  int _int(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  DateTime? _date(Object? raw) {
    if (raw is DateTime) return raw.toLocal();
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim())?.toLocal();
    }
    return null;
  }
}
