import 'package:cabine_flow/features/finances/data/repositories/supabase_phase5_finance_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_phase5_history_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Reprise historique consolidée de la Phase 5.
///
/// L'import est réservé à l'Administrateur côté Supabase. Chaque collection
/// possède son propre curseur et un document invalide stoppe le lot au lieu
/// d'être ignoré silencieusement. Les RPC Supabase sont idempotentes.
class Phase5ConsolidatedSynchronizer {
  Phase5ConsolidatedSynchronizer({
    FirebaseFirestore? firestore,
    SupabasePhase5FinanceRepository? phase5Repository,
    SupabasePhase5HistoryRepository? syncRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _phase5 = phase5Repository ?? SupabasePhase5FinanceRepository(),
       _sync = syncRepository ?? SupabasePhase5HistoryRepository();

  static const int defaultBatchSize = 100;

  final FirebaseFirestore _firestore;
  final SupabasePhase5FinanceRepository _phase5;
  final SupabasePhase5HistoryRepository _sync;
  bool _running = false;

  Future<void> synchronize({int batchSize = defaultBatchSize}) async {
    if (_running) return;
    _running = true;
    try {
      final int size = batchSize.clamp(25, 200).toInt();
      await _syncCollection(
        syncKey: 'phase5_capacities_v1',
        collection: 'agentProfiles',
        kind: 'capacity',
        batchSize: size,
        mapper: _capacityRow,
      );
      await _syncRechargeHistory(batchSize: size);
      await _syncCollection(
        syncKey: 'phase5_network_movements_v1',
        collection: 'networkTransactions',
        kind: 'network_movement',
        batchSize: size,
        mapper: _networkMovementRow,
      );
      await _syncSuccessFinalizations(batchSize: size);
      await _syncCollection(
        syncKey: 'phase5_commissions_v1',
        collection: 'commissions',
        kind: 'commission',
        batchSize: size,
        mapper: _commissionRow,
      );
      await _syncCollection(
        syncKey: 'phase5_commission_accounts_v1',
        collection: 'commissionAccounts',
        kind: 'commission_account',
        batchSize: size,
        mapper: _commissionAccountRow,
      );
      await _syncCollection(
        syncKey: 'phase5_commission_payouts_v1',
        collection: 'commissionPayouts',
        kind: 'commission_payout',
        batchSize: size,
        mapper: _commissionPayoutRow,
      );
      await _syncCollection(
        syncKey: 'phase5_supplier_accounts_v1',
        collection: 'supplierAccounts',
        kind: 'supplier_account',
        batchSize: size,
        mapper: _supplierAccountRow,
      );
      await _syncCollection(
        syncKey: 'phase5_supplier_payments_v1',
        collection: 'supplierPayments',
        kind: 'supplier_payment',
        batchSize: size,
        mapper: _supplierPaymentRow,
      );
      await _syncOrderPayments(status: 'confirmed', batchSize: size);
      await _syncOrderPayments(status: 'credit', batchSize: size);
      await _reconcileRecentState();
    } finally {
      _running = false;
    }
  }

  Future<void> _syncRechargeHistory({required int batchSize}) async {
    const String key = 'phase5_supplier_recharges_consolidated_v1';
    Phase5SyncCursor cursor = await _sync.fetchSyncCursor(key);
    if (cursor.backfillComplete) return;
    int batches = 0;
    while (true) {
      Query<Map<String, dynamic>> query = _firestore
          .collection('supplierRecharges')
          .orderBy(FieldPath.documentId)
          .limit(batchSize);
      final String? cursorId = cursor.cursorId;
      if (cursorId != null && cursorId.isNotEmpty) {
        query = query.startAfter(<Object>[cursorId]);
      }
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        await _sync.saveSyncCursor(
          key: key,
          cursorId: cursor.cursorId,
          backfillComplete: true,
        );
        return;
      }
      final List<Map<String, dynamic>> rows = snapshot.docs
          .map(_supplierRechargeRow)
          .toList(growable: false);
      await _phase5.importRechargeHistoryBatch(rows);
      final String lastId = snapshot.docs.last.id;
      final bool complete = snapshot.docs.length < batchSize;
      cursor = Phase5SyncCursor(
        key: key,
        cursorId: lastId,
        backfillComplete: complete,
      );
      await _sync.saveSyncCursor(
        key: key,
        cursorId: lastId,
        backfillComplete: complete,
      );
      batches++;
      debugPrint(
        '[Phase5][Backfill][supplier_recharge] batch=$batches rows=${rows.length} cursor=$lastId',
      );
      if (complete) return;
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
  }

  Future<void> _syncSuccessFinalizations({required int batchSize}) async {
    const String key = 'phase5_success_finalizations_v1';
    Phase5SyncCursor cursor = await _sync.fetchSyncCursor(key);
    if (cursor.backfillComplete) return;
    while (true) {
      Query<Map<String, dynamic>> query = _firestore
          .collection('networkTransactions')
          .where('type', isEqualTo: 'orderSuccess')
          .orderBy(FieldPath.documentId)
          .limit(batchSize);
      final String? cursorId = cursor.cursorId;
      if (cursorId != null && cursorId.isNotEmpty) {
        query = query.startAfter(<Object>[cursorId]);
      }
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        await _sync.saveSyncCursor(
          key: key,
          cursorId: cursor.cursorId,
          backfillComplete: true,
        );
        return;
      }
      final List<Map<String, dynamic>> rows = snapshot.docs
          .map(_successFinalizationRow)
          .toList(growable: false);
      await _phase5.importSuccessFinalizations(rows);
      final String lastId = snapshot.docs.last.id;
      final bool complete = snapshot.docs.length < batchSize;
      cursor = Phase5SyncCursor(
        key: key,
        cursorId: lastId,
        backfillComplete: complete,
      );
      await _sync.saveSyncCursor(
        key: key,
        cursorId: lastId,
        backfillComplete: complete,
      );
      if (complete) return;
    }
  }

  Future<void> _reconcileRecentState() async {
    // Les backfills ci-dessus sont finis une seule fois. Ce passage court
    // réconcilie ensuite les écritures qui auraient réussi dans Firebase alors
    // que Supabase était temporairement indisponible.
    final QuerySnapshot<Map<String, dynamic>> profiles = await _firestore
        .collection('agentProfiles')
        .orderBy(FieldPath.documentId)
        .limit(1000)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in profiles.docs) {
      await _phase5.reconcileCapacitySnapshot(_capacityRow(doc));
    }

    final QuerySnapshot<Map<String, dynamic>> movements = await _firestore
        .collection('networkTransactions')
        .orderBy('createdAt', descending: true)
        .limit(300)
        .get();
    if (movements.docs.isNotEmpty) {
      await _phase5.importLegacyBatch(
        kind: 'network_movement',
        rows: movements.docs.map(_networkMovementRow).toList(growable: false),
      );
      final List<Map<String, dynamic>> finalizations = movements.docs
          .where((doc) => doc.data()['type'] == 'orderSuccess')
          .map(_successFinalizationRow)
          .toList(growable: false);
      await _phase5.importSuccessFinalizations(finalizations);
    }

    await _reconcileRecentCollection(
      collection: 'commissions',
      orderField: 'earnedAt',
      kind: 'commission',
      mapper: _commissionRow,
    );
    await _reconcileRecentCollection(
      collection: 'commissionPayouts',
      orderField: 'paidAt',
      kind: 'commission_payout',
      mapper: _commissionPayoutRow,
    );
    await _reconcileRecentRechargeHistory();
    await _reconcileRecentCollection(
      collection: 'supplierPayments',
      orderField: 'paidAt',
      kind: 'supplier_payment',
      mapper: _supplierPaymentRow,
    );

    final QuerySnapshot<Map<String, dynamic>> commissionAccounts =
        await _firestore.collection('commissionAccounts').limit(1000).get();
    if (commissionAccounts.docs.isNotEmpty) {
      await _phase5.importLegacyBatch(
        kind: 'commission_account',
        rows: commissionAccounts.docs
            .map(_commissionAccountRow)
            .toList(growable: false),
      );
    }
    final QuerySnapshot<Map<String, dynamic>> supplierAccounts =
        await _firestore.collection('supplierAccounts').limit(1000).get();
    if (supplierAccounts.docs.isNotEmpty) {
      await _phase5.importLegacyBatch(
        kind: 'supplier_account',
        rows: supplierAccounts.docs
            .map(_supplierAccountRow)
            .toList(growable: false),
      );
    }

    final QuerySnapshot<Map<String, dynamic>> recentOrders = await _firestore
        .collection('orders')
        .orderBy('updatedAt', descending: true)
        .limit(300)
        .get();
    final List<Map<String, dynamic>> payments = recentOrders.docs
        .where((doc) {
          final Object? value = doc.data()['paymentStatus'];
          return value == 'confirmed' || value == 'credit';
        })
        .map(_orderPaymentRow)
        .toList(growable: false);
    if (payments.isNotEmpty) {
      await _phase5.importLegacyBatch(kind: 'order_payment', rows: payments);
    }
  }

  Future<void> _reconcileRecentCollection({
    required String collection,
    required String orderField,
    required String kind,
    required Map<String, dynamic> Function(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
    ) mapper,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection(collection)
        .orderBy(orderField, descending: true)
        .limit(300)
        .get();
    if (snapshot.docs.isEmpty) return;
    await _phase5.importLegacyBatch(
      kind: kind,
      rows: snapshot.docs.map(mapper).toList(growable: false),
    );
  }

  Future<void> _reconcileRecentRechargeHistory() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('supplierRecharges')
        .orderBy('createdAt', descending: true)
        .limit(300)
        .get();
    if (snapshot.docs.isEmpty) return;
    await _phase5.importRechargeHistoryBatch(
      snapshot.docs.map(_supplierRechargeRow).toList(growable: false),
    );
  }

  Future<void> _syncOrderPayments({
    required String status,
    required int batchSize,
  }) {
    return _syncCollection(
      syncKey: 'phase5_order_payments_${status}_v1',
      collection: 'orders',
      kind: 'order_payment',
      batchSize: batchSize,
      queryBuilder: (CollectionReference<Map<String, dynamic>> collection) =>
          collection.where('paymentStatus', isEqualTo: status),
      mapper: _orderPaymentRow,
    );
  }

  Future<void> _syncCollection({
    required String syncKey,
    required String collection,
    required String kind,
    required int batchSize,
    required Map<String, dynamic> Function(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
    ) mapper,
    Query<Map<String, dynamic>> Function(
      CollectionReference<Map<String, dynamic>> collection,
    )? queryBuilder,
  }) async {
    Phase5SyncCursor cursor = await _sync.fetchSyncCursor(syncKey);
    if (cursor.backfillComplete) return;
    int batches = 0;
    while (true) {
      final CollectionReference<Map<String, dynamic>> reference = _firestore
          .collection(collection);
      Query<Map<String, dynamic>> query =
          (queryBuilder?.call(reference) ?? reference)
              .orderBy(FieldPath.documentId)
              .limit(batchSize);
      final String? cursorId = cursor.cursorId;
      if (cursorId != null && cursorId.isNotEmpty) {
        query = query.startAfter(<Object>[cursorId]);
      }
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        await _sync.saveSyncCursor(
          key: syncKey,
          cursorId: cursor.cursorId,
          backfillComplete: true,
        );
        return;
      }
      final List<Map<String, dynamic>> rows = snapshot.docs
          .map(mapper)
          .toList(growable: false);
      await _phase5.importLegacyBatch(kind: kind, rows: rows);
      final String lastId = snapshot.docs.last.id;
      final bool complete = snapshot.docs.length < batchSize;
      cursor = Phase5SyncCursor(
        key: syncKey,
        cursorId: lastId,
        backfillComplete: complete,
      );
      await _sync.saveSyncCursor(
        key: syncKey,
        cursorId: lastId,
        backfillComplete: complete,
      );
      batches++;
      debugPrint(
        '[Phase5][Backfill][$kind] batch=$batches rows=${rows.length} cursor=$lastId',
      );
      if (complete) return;
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
  }

  Map<String, dynamic> _capacityRow(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    return <String, dynamic>{
      'agent_id': doc.id,
      'agent_name': _requiredName(data['name'] ?? data['displayName'], doc.id),
      'orange_capacity': _nonNegative(data['orangeCapacity'], doc.id),
      'mtn_capacity': _nonNegative(data['mtnCapacity'], doc.id),
      'moov_capacity': _nonNegative(data['moovCapacity'], doc.id),
    };
  }

  Map<String, dynamic> _supplierRechargeRow(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    return <String, dynamic>{
      'source_firestore_id': doc.id,
      'supplier_id': _required(data['supplierId'], 'supplierId', doc.id),
      'supplier_name': _requiredName(data['supplierName'], doc.id),
      'agent_id': _required(data['agentId'], 'agentId', doc.id),
      'agent_name': _requiredName(data['agentName'], doc.id),
      'network': _network(data['network'], doc.id),
      'principal_amount': _positive(data['principalAmount'], 'principalAmount', doc.id),
      'bonus_amount': _nonNegative(data['bonusAmount'], doc.id),
      'received_amount': _positive(data['receivedAmount'], 'receivedAmount', doc.id),
      'amount_owed': _nonNegative(data['amountOwed'], doc.id),
      'capacity_before': _nonNegative(data['capacityBefore'], doc.id),
      'capacity_after': _nonNegative(data['capacityAfter'], doc.id),
      'note': _nullable(data['note']),
      'occurred_at': _requiredDate(data['createdAt'], 'createdAt', doc.id),
      'created_by_uid': _nullable(data['createdBy']),
      'created_by_name': _nullable(data['createdByName']),
    };
  }

  Map<String, dynamic> _networkMovementRow(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final String direction = _required(data['direction'], 'direction', doc.id);
    final String type = _required(data['type'], 'type', doc.id);
    if (direction != 'incoming' && direction != 'outgoing') {
      throw StateError('networkTransactions/${doc.id}: direction invalide.');
    }
    if (!const <String>{'orderSuccess', 'supplierRecharge', 'manualAdjustment'}.contains(type)) {
      throw StateError('networkTransactions/${doc.id}: type invalide.');
    }
    final String? orderId = _nullable(data['orderId']);
    final String? rechargeId = _nullable(data['supplierRechargeId']);
    final String sourceKey = type == 'orderSuccess' && orderId != null
        ? 'order:$orderId'
        : type == 'supplierRecharge' && rechargeId != null
        ? 'recharge:$rechargeId'
        : doc.id;
    return <String, dynamic>{
      'source_key': sourceKey,
      'network': _network(data['network'], doc.id),
      'direction': direction,
      'movement_type': type,
      'amount': _positive(data['amount'], 'amount', doc.id),
      'capacity_before': _nonNegative(data['capacityBefore'], doc.id),
      'capacity_after': _nonNegative(data['capacityAfter'], doc.id),
      'agent_id': _required(data['agentId'], 'agentId', doc.id),
      'agent_name': _requiredName(data['agentName'], doc.id),
      'order_id': _nullable(data['orderId']),
      'order_reference': _nullable(data['orderReference']),
      'supplier_id': _nullable(data['supplierId']),
      'supplier_name': _nullable(data['supplierName']),
      'supplier_recharge_id': _nullable(data['supplierRechargeId']),
      'created_by_uid': _nullable(data['createdBy']) ?? 'migration',
      'created_by_name': _nullable(data['createdByName']),
      'occurred_at': _requiredDate(data['createdAt'], 'createdAt', doc.id),
    };
  }

  Map<String, dynamic> _successFinalizationRow(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    if (_required(data['type'], 'type', doc.id) != 'orderSuccess') {
      throw StateError('networkTransactions/${doc.id}: succès attendu.');
    }
    return <String, dynamic>{
      'order_id': _required(data['orderId'], 'orderId', doc.id),
      'order_reference': _required(
        data['orderReference'],
        'orderReference',
        doc.id,
      ),
      'agent_id': _required(data['agentId'], 'agentId', doc.id),
      'agent_name': _requiredName(data['agentName'], doc.id),
      'network': _network(data['network'], doc.id),
      'order_amount': _positive(data['amount'], 'amount', doc.id),
      'capacity_before': _nonNegative(data['capacityBefore'], doc.id),
      'capacity_after': _nonNegative(data['capacityAfter'], doc.id),
      'commission_amount': 10,
      'completed_at': _requiredDate(data['createdAt'], 'createdAt', doc.id),
    };
  }

  Map<String, dynamic> _commissionRow(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    return <String, dynamic>{
      'source_firestore_id': doc.id,
      'order_id': _required(data['orderId'], 'orderId', doc.id),
      'order_reference': _required(data['orderReference'], 'orderReference', doc.id),
      'agent_id': _required(data['agentId'], 'agentId', doc.id),
      'agent_name': _requiredName(data['agentName'], doc.id),
      'network': _network(data['network'], doc.id),
      'order_amount': _positive(data['orderAmount'], 'orderAmount', doc.id),
      'commission_amount': _positive(data['commissionAmount'], 'commissionAmount', doc.id),
      'policy_id': _nullable(data['policyId']) ?? 'fixed-10-v1',
      'policy_type': _nullable(data['policyType']) ?? 'fixedPerSuccessfulTransaction',
      'rate': _positive(data['rate'], 'rate', doc.id),
      'processing_started_at': _optionalDate(data['processingStartedAt']),
      'earned_at': _requiredDate(data['earnedAt'], 'earnedAt', doc.id),
    };
  }

  Map<String, dynamic> _commissionAccountRow(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    return <String, dynamic>{
      'agent_id': _nullable(data['agentId']) ?? doc.id,
      'agent_name': _requiredName(data['agentName'], doc.id),
      'earned_total': _nonNegative(data['earnedTotal'], doc.id),
      'paid_total': _nonNegative(data['paidTotal'], doc.id),
      'earned_transactions': _nonNegative(data['earnedTransactions'], doc.id),
      'last_commission_order_id': _nullable(data['lastCommissionOrderId']),
      'created_at': _optionalDate(data['createdAt']) ??
          _optionalDate(data['updatedAt']) ??
          DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _commissionPayoutRow(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    return <String, dynamic>{
      'source_firestore_id': doc.id,
      'agent_id': _required(data['agentId'], 'agentId', doc.id),
      'agent_name': _requiredName(data['agentName'], doc.id),
      'amount': _positive(data['amount'], 'amount', doc.id),
      'payment_channel': _nullable(data['paymentChannel']) ?? 'wave',
      'payment_reference': _required(data['paymentReference'], 'paymentReference', doc.id),
      'note': _nullable(data['note']),
      'paid_at': _requiredDate(data['paidAt'], 'paidAt', doc.id),
      'created_by_uid': _nullable(data['createdBy']) ?? 'migration',
      'created_by_name': _nullable(data['createdByName']) ?? 'Migration',
    };
  }

  Map<String, dynamic> _supplierAccountRow(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    return <String, dynamic>{
      'supplier_id': _nullable(data['supplierId']) ?? doc.id,
      'supplier_name': _requiredName(data['supplierName'], doc.id),
      'total_owed': _nonNegative(data['totalOwed'], doc.id),
      'total_paid': _nonNegative(data['totalPaid'], doc.id),
      'total_recharged': _nonNegative(data['totalRecharged'], doc.id),
      'recharge_count': _nonNegative(data['rechargeCount'], doc.id),
      'last_recharge_id': _nullable(data['lastRechargeId']),
      'created_at': _optionalDate(data['createdAt']) ??
          _optionalDate(data['updatedAt']) ??
          DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _supplierPaymentRow(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    return <String, dynamic>{
      'source_firestore_id': doc.id,
      'supplier_id': _required(data['supplierId'], 'supplierId', doc.id),
      'supplier_name': _requiredName(data['supplierName'], doc.id),
      'amount': _positive(data['amount'], 'amount', doc.id),
      'payment_channel': _required(data['paymentChannel'], 'paymentChannel', doc.id),
      'payment_reference': _required(data['paymentReference'], 'paymentReference', doc.id),
      'note': _nullable(data['note']),
      'paid_at': _requiredDate(data['paidAt'], 'paidAt', doc.id),
      'created_by_uid': _nullable(data['createdBy']) ?? 'migration',
      'created_by_name': _nullable(data['createdByName']) ?? 'Migration',
    };
  }

  Map<String, dynamic> _orderPaymentRow(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final String status = _required(data['paymentStatus'], 'paymentStatus', doc.id);
    if (status != 'confirmed' && status != 'credit') {
      throw StateError('orders/${doc.id}: paiement non migrable.');
    }
    return <String, dynamic>{
      'order_id': doc.id,
      'order_reference': _required(data['reference'], 'reference', doc.id),
      'amount': _positive(data['amount'], 'amount', doc.id),
      'payment_status': status,
      'payment_reference': _nullable(data['paymentReference']),
      'payer_name': _nullable(data['paymentPayerName'] ?? data['payerName']),
      'payment_channel': _nullable(data['paymentChannel']) ??
          (status == 'credit' ? 'credit' : 'wave'),
      'paid_at': _optionalDate(data['paidAt']),
      'confirmed_at': _optionalDate(data['paymentConfirmedAt']),
      'source': _nullable(data['source']) ?? 'operatorApp',
      'created_at': _optionalDate(data['createdAt']) ??
          DateTime.now().toUtc().toIso8601String(),
    };
  }

  String _required(Object? value, String field, String id) {
    final String text = value is String ? value.trim() : '';
    if (text.isEmpty) throw StateError('$id: champ $field invalide.');
    return text;
  }

  String _requiredName(Object? value, String id) {
    final String text = value is String ? value.trim() : '';
    if (text.length < 2) throw StateError('$id: nom invalide.');
    return text;
  }

  String? _nullable(Object? value) {
    final String text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }

  int _nonNegative(Object? value, String id) {
    final int amount = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    if (amount < 0) throw StateError('$id: montant négatif invalide.');
    return amount;
  }

  int _positive(Object? value, String field, String id) {
    final int amount = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    if (amount <= 0) throw StateError('$id: champ $field invalide.');
    return amount;
  }

  String _network(Object? value, String id) {
    final String network = value is String ? value.trim().toLowerCase() : '';
    if (!const <String>{'orange', 'mtn', 'moov'}.contains(network)) {
      throw StateError('$id: réseau invalide.');
    }
    return network;
  }

  String _requiredDate(Object? value, String field, String id) {
    final String? date = _optionalDate(value);
    if (date == null) throw StateError('$id: date $field invalide.');
    return date;
  }

  String? _optionalDate(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is String) return DateTime.tryParse(value)?.toUtc().toIso8601String();
    return null;
  }
}
