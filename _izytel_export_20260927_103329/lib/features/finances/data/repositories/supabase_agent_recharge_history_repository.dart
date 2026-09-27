import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/finances/domain/models/agent_recharge_history_models.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/agent_recharge_history_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAgentRechargeHistoryRepository
    implements AgentRechargeHistoryRepository {
  SupabaseAgentRechargeHistoryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<AgentRechargeHistoryPageData> fetchPage({
    required String agentId,
    AgentRechargeHistoryCursor? cursor,
    AgentRechargeHistoryFilter filter = const AgentRechargeHistoryFilter(),
    int pageSize = 50,
  }) async {
    _requireCurrentAgent(agentId);
    final int safePageSize = pageSize.clamp(1, 100).toInt();
    final Object? raw = await _client.rpc(
      'phase5_agent_recharge_page',
      params: <String, dynamic>{
        'p_limit': safePageSize + 1,
        'p_cursor_at': cursor?.occurredAt.toUtc().toIso8601String(),
        'p_cursor_id': cursor?.rowId,
        'p_network': filter.network?.firestoreValue,
        'p_search': _nullable(filter.searchQuery),
        'p_from': filter.from?.toUtc().toIso8601String(),
        'p_to': filter.to?.toUtc().toIso8601String(),
      },
    );

    final List<Map<String, dynamic>> rows = _rows(raw);
    final bool hasMore = rows.length > safePageSize;
    final List<Map<String, dynamic>> pageRows = hasMore
        ? rows.take(safePageSize).toList(growable: false)
        : rows;
    final List<SupplierRecharge> items = pageRows
        .map(_fromRow)
        .whereType<SupplierRecharge>()
        .toList(growable: false);

    AgentRechargeHistoryCursor? nextCursor;
    if (hasMore && pageRows.isNotEmpty) {
      final Map<String, dynamic> last = pageRows.last;
      final DateTime? occurredAt = _date(last['occurred_at']);
      final String rowId = _string(last['id']);
      if (occurredAt != null && rowId.isNotEmpty) {
        nextCursor = AgentRechargeHistoryCursor(
          occurredAt: occurredAt,
          rowId: rowId,
        );
      }
    }

    return AgentRechargeHistoryPageData(
      items: List<SupplierRecharge>.unmodifiable(items),
      hasMore: hasMore && nextCursor != null,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<AgentRechargeHistorySummary> fetchSummary({
    required String agentId,
    AgentRechargeHistoryFilter filter = const AgentRechargeHistoryFilter(),
  }) async {
    _requireCurrentAgent(agentId);
    final Object? raw = await _client.rpc(
      'phase5_agent_recharge_summary_v2',
      params: <String, dynamic>{
        'p_network': filter.network?.firestoreValue,
        'p_search': _nullable(filter.searchQuery),
        'p_from': filter.from?.toUtc().toIso8601String(),
        'p_to': filter.to?.toUtc().toIso8601String(),
      },
    );
    final List<Map<String, dynamic>> rows = _rows(raw);
    final Map<String, dynamic> row = rows.isEmpty
        ? const <String, dynamic>{}
        : rows.first;
    return AgentRechargeHistorySummary(
      totalCount: _int(row['total_count']),
      totalReceived: _int(row['total_received']),
      totalBonus: _int(row['total_bonus']),
    );
  }

  void _requireCurrentAgent(String agentId) {
    final String uid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (uid.isEmpty) throw StateError('Aucune session Firebase active.');
    if (uid != agentId.trim()) {
      throw StateError('Cette session ne correspond pas à l’Agent demandé.');
    }
  }

  SupplierRecharge? _fromRow(Map<String, dynamic> row) {
    final AgentNetwork? network = _network(row['network']);
    final DateTime? occurredAt = _date(row['occurred_at']);
    final String sourceId = _string(row['source_firestore_id']);
    if (network == null || occurredAt == null || sourceId.isEmpty) return null;
    return SupplierRecharge(
      id: sourceId,
      supplierId: _string(row['supplier_id']),
      supplierName: _string(row['supplier_name']),
      agentId: _string(row['agent_id']),
      agentName: _string(row['agent_name']),
      network: network,
      principalAmount: _int(row['principal_amount']),
      bonusAmount: _int(row['bonus_amount']),
      receivedAmount: _int(row['received_amount']),
      amountOwed: _int(row['amount_owed']),
      capacityBefore: _int(row['capacity_before']),
      capacityAfter: _int(row['capacity_after']),
      note: _nullable(row['note']),
      createdAt: occurredAt,
      createdBy: _string(row['created_by_uid']),
      createdByName: _string(row['created_by_name']),
    );
  }

  List<Map<String, dynamic>> _rows(Object? raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((Map value) => Map<String, dynamic>.from(value))
        .toList(growable: false);
  }

  AgentNetwork? _network(Object? value) {
    final String text = _string(value).toLowerCase();
    for (final AgentNetwork item in AgentNetwork.values) {
      if (item.firestoreValue == text) return item;
    }
    return null;
  }

  DateTime? _date(Object? value) {
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
