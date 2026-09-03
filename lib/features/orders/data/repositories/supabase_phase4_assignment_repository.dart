import 'package:cabine_flow/features/orders/domain/models/automatic_assignment.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/foundation.dart';
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
  final DateTime updatedAt;

  bool get isAssigned => assignmentState == 'assigned';
  bool get isAccepted => assignmentState == 'accepted';
  bool get isHandedOff => assignmentState == 'handed_off';
  bool get isManualRequired => assignmentState == 'manual_required';
  bool get isWaiting => assignmentState == 'waiting';

  bool get reservesCapacityInSupabase {
    return firebaseAssignmentSyncedAt == null &&
        (assignmentState == 'assigned' || assignmentState == 'accepted') &&
        assignedAgentId != null;
  }

  QueueOrder toPendingQueueOrder({
    List<String> refusedAgentIds = const <String>[],
  }) {
    return QueueOrder(
      id: orderId,
      reference: orderReference,
      source: source,
      clientName: clientName,
      clientWhatsappPhone: clientWhatsappPhone,
      network: network,
      beneficiaryPhone: beneficiaryPhone,
      operationType: operationType,
      offerLabel: offerLabel,
      amount: amount,
      originalWhatsappMessage: originalWhatsappMessage,
      internalNotes: internalNotes,
      createdAt: firebaseCreatedAt,
      paidAt: paidAt,
      paymentPayerName: paymentPayerName,
      paymentConfirmedAt: paymentConfirmedAt,
      paymentReference: paymentReference,
      status: QueueOrderStatus.paidReady,
      paymentStatus: paymentStatus,
      assignedAgentId: assignedAgentId,
      assignedAgentName: assignedAgentName,
      assignedByUserId: assignedByUid,
      assignedAt: assignedAt,
      assignmentMode: assignmentMode,
      assignmentStatus: isAccepted || isHandedOff
          ? OrderAssignmentStatus.accepted
          : isAssigned
          ? OrderAssignmentStatus.assigned
          : OrderAssignmentStatus.unassigned,
      lastAssignmentRefusalReason: lastRefusalReason,
      lastAssignmentRefusedAt: lastRefusedAt,
      lastAssignmentRefusedAgentId: lastRefusedAgentId,
      autoAssignmentRefusedAgentIds: refusedAgentIds,
      manualAssignmentRequired: isManualRequired,
    );
  }

  QueueOrder overlayOn(
    QueueOrder order, {
    List<String> refusedAgentIds = const <String>[],
  }) {
    if (isWaiting || isManualRequired) {
      return order.copyWith(
        clearAgentAssignment: true,
        lastAssignmentRefusalReason: lastRefusalReason,
        lastAssignmentRefusedAt: lastRefusedAt,
        lastAssignmentRefusedAgentId: lastRefusedAgentId,
        autoAssignmentRefusedAgentIds: refusedAgentIds,
        manualAssignmentRequired: isManualRequired,
      );
    }

    return order.copyWith(
      assignedAgentId: assignedAgentId,
      assignedAgentName: assignedAgentName,
      assignedByUserId: assignedByUid,
      assignedAt: assignedAt,
      assignmentMode: assignmentMode,
      assignmentStatus: isAccepted || isHandedOff
          ? OrderAssignmentStatus.accepted
          : OrderAssignmentStatus.assigned,
      lastAssignmentRefusalReason: lastRefusalReason,
      lastAssignmentRefusedAt: lastRefusedAt,
      lastAssignmentRefusedAgentId: lastRefusedAgentId,
      autoAssignmentRefusedAgentIds: refusedAgentIds,
      manualAssignmentRequired: false,
    );
  }
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
      'phase4_sync_order',
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

  Future<Phase4AssignmentSnapshot> accept(String orderId) async {
    await _agentAction(orderId: orderId, action: 'accept');
    final Phase4AssignmentSnapshot? snapshot = await fetchOrder(orderId);
    if (snapshot == null || !snapshot.isAccepted) {
      throw StateError('L’acceptation Supabase n’a pas pu être confirmée.');
    }
    return snapshot;
  }

  Future<void> refuse({required String orderId, required String reason}) {
    return _agentAction(
      orderId: orderId,
      action: 'refuse',
      reason: reason.trim(),
    );
  }

  Future<void> _agentAction({
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
    if (raw is Map && raw['ok'] == true) return;
    throw StateError('La transition Supabase Phase 4 a échoué.');
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
    while (true) {
      try {
        final List<Phase4AssignmentSnapshot> value = await fetchAllForStaff();
        lastSuccessful = value;
        yield value;
      } catch (error, stackTrace) {
        debugPrint('[Phase4Assignment][staff-watch] $error');
        debugPrintStack(stackTrace: stackTrace);
        if (lastSuccessful == null) rethrow;
      }
      await Future<void>.delayed(pollInterval);
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
    while (true) {
      try {
        final Phase4AgentAssignmentState value =
            await fetchAgentAssignmentState(agentId);
        lastSuccessful = value;
        yield value;
      } catch (error, stackTrace) {
        debugPrint('[Phase4Assignment][agent-watch] $error');
        debugPrintStack(stackTrace: stackTrace);
        if (lastSuccessful == null) rethrow;
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  Stream<List<Phase4AssignmentSnapshot>> watchAgentAssignments(String agentId) {
    return watchAgentAssignmentState(
      agentId,
    ).map((Phase4AgentAssignmentState value) => value.currentAssignments);
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
    while (true) {
      try {
        final List<Phase4RefusalHistorySnapshot> value =
            await fetchAgentRefusalHistory(agentId);
        lastSuccessful = value;
        yield value;
      } catch (error, stackTrace) {
        debugPrint('[Phase4Assignment][refusal-history] $error');
        debugPrintStack(stackTrace: stackTrace);
        if (lastSuccessful == null) rethrow;
      }
      await Future<void>.delayed(pollInterval);
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
    while (true) {
      try {
        final List<QueueOrder> value = await fetchAgentRefusedOrders(agentId);
        lastSuccessful = value;
        yield value;
      } catch (error, stackTrace) {
        debugPrint('[Phase4Assignment][refused-orders] $error');
        debugPrintStack(stackTrace: stackTrace);
        if (lastSuccessful == null) rethrow;
      }
      await Future<void>.delayed(pollInterval);
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
      updatedAt: updatedAt,
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
