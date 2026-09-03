import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_phase5_history_repository.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class Phase5RechargeHistorySynchronizer {
  Phase5RechargeHistorySynchronizer({
    FirebaseFirestore? firestore,
    SupabasePhase5HistoryRepository? phase5Repository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _phase5 = phase5Repository ?? SupabasePhase5HistoryRepository();

  static const String syncKey = 'supplier_recharges_v1';
  static const int defaultBatchSize = 100;

  final FirebaseFirestore _firestore;
  final SupabasePhase5HistoryRepository _phase5;
  bool _running = false;

  Future<void> synchronize({int batchSize = defaultBatchSize}) async {
    if (_running) return;
    _running = true;
    try {
      final int safeBatchSize = batchSize.clamp(25, 250).toInt();
      Phase5SyncCursor cursor = await _phase5.fetchSyncCursor(syncKey);
      int batchCount = 0;

      while (true) {
        Query<Map<String, dynamic>> query = _firestore
            .collection('supplierRecharges')
            .orderBy('createdAt')
            .orderBy(FieldPath.documentId)
            .limit(safeBatchSize);

        if (cursor.cursorAt != null && cursor.cursorId != null) {
          query = query.startAfter(<Object>[
            Timestamp.fromDate(cursor.cursorAt!.toUtc()),
            cursor.cursorId!,
          ]);
        }

        final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
        if (snapshot.docs.isEmpty) {
          await _phase5.saveSyncCursor(
            key: syncKey,
            cursorAt: cursor.cursorAt,
            cursorId: cursor.cursorId,
            backfillComplete: true,
          );
          break;
        }

        final List<SupplierRecharge> values = snapshot.docs
            .map(_mapRecharge)
            .whereType<SupplierRecharge>()
            .toList(growable: false);
        await _phase5.upsertSupplierRecharges(values);

        final QueryDocumentSnapshot<Map<String, dynamic>> last =
            snapshot.docs.last;
        final DateTime? lastDate = _date(last.data()['createdAt']);
        if (lastDate == null) {
          throw StateError(
            'Une recharge Firebase ne possède pas de date valide.',
          );
        }
        cursor = Phase5SyncCursor(
          key: syncKey,
          cursorAt: lastDate,
          cursorId: last.id,
          backfillComplete: snapshot.docs.length < safeBatchSize,
        );
        await _phase5.saveSyncCursor(
          key: syncKey,
          cursorAt: cursor.cursorAt,
          cursorId: cursor.cursorId,
          backfillComplete: cursor.backfillComplete,
        );
        batchCount++;
        debugPrint(
          '[Phase5][RechargeSync] batch=$batchCount rows=${values.length} '
          'cursor=${last.id}',
        );

        if (snapshot.docs.length < safeBatchSize) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    } finally {
      _running = false;
    }
  }

  SupplierRecharge? _mapRecharge(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final AgentNetwork? network = _network(data['network']);
    final DateTime? createdAt = _date(data['createdAt']);
    final String supplierName = _string(data['supplierName']);
    final String agentName = _string(data['agentName']);
    if (network == null ||
        createdAt == null ||
        supplierName.length < 2 ||
        agentName.length < 2) {
      return null;
    }
    return SupplierRecharge(
      id: doc.id,
      supplierId: _string(data['supplierId']),
      supplierName: supplierName,
      agentId: _string(data['agentId']),
      agentName: agentName,
      network: network,
      principalAmount: _int(data['principalAmount']),
      bonusAmount: _int(data['bonusAmount']),
      receivedAmount: _int(data['receivedAmount']),
      amountOwed: _int(data['amountOwed']),
      capacityBefore: _int(data['capacityBefore']),
      capacityAfter: _int(data['capacityAfter']),
      note: _nullable(data['note']),
      createdAt: createdAt,
      createdBy: _string(data['createdBy']),
      createdByName: _string(data['createdByName']),
    );
  }

  AgentNetwork? _network(Object? value) {
    final String text = _string(value).toLowerCase();
    for (final AgentNetwork item in AgentNetwork.values) {
      if (item.firestoreValue == text) return item;
    }
    return null;
  }

  DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }

  int _int(Object? value) => value is num ? value.toInt() : 0;
  String _string(Object? value) => value is String ? value.trim() : '';
  String? _nullable(Object? value) {
    final String text = _string(value);
    return text.isEmpty ? null : text;
  }
}
