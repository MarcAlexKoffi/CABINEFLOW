import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Phase5SyncCursor {
  const Phase5SyncCursor({
    required this.key,
    required this.backfillComplete,
    this.cursorAt,
    this.cursorId,
  });

  final String key;
  final DateTime? cursorAt;
  final String? cursorId;
  final bool backfillComplete;
}

class SupabasePhase5HistoryRepository {
  SupabasePhase5HistoryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String rechargeTable = 'phase5_agent_recharges';
  static const String syncStateTable = 'phase5_sync_state';

  final SupabaseClient _client;

  Future<void> upsertSupplierRecharges(List<SupplierRecharge> recharges) async {
    if (recharges.isEmpty) return;
    _requireStaffSession();
    final List<Map<String, dynamic>> rows = recharges
        .map(
          (SupplierRecharge value) => <String, dynamic>{
            'source_firestore_id': value.id,
            'supplier_id': value.supplierId,
            'supplier_name': value.supplierName.trim(),
            'agent_id': value.agentId,
            'agent_name': value.agentName.trim(),
            'network': value.network.firestoreValue,
            'principal_amount': value.principalAmount,
            'bonus_amount': value.bonusAmount,
            'received_amount': value.receivedAmount,
            'amount_owed': value.amountOwed,
            'capacity_before': value.capacityBefore,
            'capacity_after': value.capacityAfter,
            'note': _nullable(value.note),
            'occurred_at': value.createdAt.toUtc().toIso8601String(),
            'created_by_uid': _nullable(value.createdBy),
            'created_by_name': _nullable(value.createdByName),
          },
        )
        .toList(growable: false);
    await _client.rpc(
      'phase5_import_recharge_history_batch',
      params: <String, dynamic>{'p_rows': rows},
    );
  }

  Future<Phase5SyncCursor> fetchSyncCursor(String key) async {
    _requireStaffSession();
    final List<Map<String, dynamic>> rows = await _client
        .from(syncStateTable)
        .select()
        .eq('sync_key', key)
        .limit(1);
    if (rows.isEmpty) {
      return Phase5SyncCursor(key: key, backfillComplete: false);
    }
    final Map<String, dynamic> row = rows.first;
    return Phase5SyncCursor(
      key: key,
      cursorAt: _date(row['cursor_at']),
      cursorId: _nullable(row['cursor_id']),
      backfillComplete: row['backfill_complete'] == true,
    );
  }

  Future<void> saveSyncCursor({
    required String key,
    DateTime? cursorAt,
    String? cursorId,
    required bool backfillComplete,
  }) async {
    _requireStaffSession();
    await _client.from(syncStateTable).upsert(<String, dynamic>{
      'sync_key': key,
      'cursor_at': cursorAt?.toUtc().toIso8601String(),
      'cursor_id': _nullable(cursorId),
      'backfill_complete': backfillComplete,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'sync_key');
  }

  void _requireStaffSession() {
    final String uid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (uid.isEmpty) throw StateError('Aucune session Firebase active.');
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value.toLocal();
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }

  String? _nullable(Object? value) {
    final String text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }
}
