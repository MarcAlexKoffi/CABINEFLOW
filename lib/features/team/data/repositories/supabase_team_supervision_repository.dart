import 'package:cabine_flow/features/team/domain/models/team_supervision_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTeamSupervisionRepository {
  SupabaseTeamSupervisionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<TeamScopeSnapshot> fetchScope() async {
    final Object? raw = await _client.rpc('izytel_team_scope_snapshot');
    return TeamScopeSnapshot.fromMap(_rpcMap(raw));
  }

  Future<TeamMemberDetail> fetchMemberDetail({
    required String actorType,
    required String actorId,
  }) async {
    final Object? raw = await _client.rpc(
      'izytel_team_member_detail',
      params: <String, dynamic>{
        'p_actor_type': actorType,
        'p_actor_id': actorId,
      },
    );
    final Map<String, dynamic> payload = _rpcMap(raw);
    final String normalizedType = actorType.trim().toLowerCase();
    final Object? financeRaw = payload['finance'];
    final Map<String, dynamic> finance = financeRaw is Map
        ? Map<String, dynamic>.from(financeRaw)
        : <String, dynamic>{};

    if (normalizedType == 'manager') {
      final List<Map<String, dynamic>> managerFinance =
          await Future.wait<Map<String, dynamic>>(
        <Future<Map<String, dynamic>>>[
          fetchManagerCompensationPreview(managerId: actorId),
          fetchManagerCompensationHistory(managerId: actorId),
        ],
      );
      finance['compensationPreview'] = managerFinance[0];
      finance['compensationHistory'] = managerFinance[1];
    } else if (normalizedType == 'agent' || normalizedType == 'cabiniste') {
      finance['activityHistory'] = await fetchMemberActivityHistory(
        actorType: normalizedType,
        actorId: actorId,
      );
    }
    payload['finance'] = finance;
    return TeamMemberDetail.fromMap(payload);
  }

  Future<Map<String, dynamic>> fetchMemberActivityHistory({
    required String actorType,
    required String actorId,
    int limit = 25,
  }) async {
    final Object? raw = await _client.rpc(
      'izytel_team_member_activity_history',
      params: <String, dynamic>{
        'p_actor_type': actorType.trim().toLowerCase(),
        'p_actor_id': actorId.trim(),
        'p_limit': limit,
      },
    );
    return _rpcMap(raw);
  }

  Future<Map<String, dynamic>> fetchManagerCompensationPreview({
    String? managerId,
    DateTime? periodStart,
  }) async {
    final Object? raw = await _client.rpc(
      'izytel_manager_compensation_preview',
      params: <String, dynamic>{
        'p_manager_id': managerId,
        'p_period_start': periodStart == null ? null : _dateOnly(periodStart),
      },
    );
    return _rpcMap(raw);
  }

  Future<Map<String, dynamic>> fetchManagerCompensationHistory({
    String? managerId,
    int limit = 24,
  }) async {
    final Object? raw = await _client.rpc(
      'izytel_manager_compensation_history',
      params: <String, dynamic>{
        'p_manager_id': managerId,
        'p_limit': limit,
      },
    );
    return _rpcMap(raw);
  }

  Future<Map<String, dynamic>> closeManagerCompensationPeriod({
    required String managerId,
    required DateTime periodStart,
  }) async {
    final Object? raw = await _client.rpc(
      'izytel_admin_close_manager_compensation_period',
      params: <String, dynamic>{
        'p_manager_id': managerId,
        'p_period_start': _dateOnly(periodStart),
      },
    );
    return _rpcMap(raw);
  }

  Future<Map<String, dynamic>> approveManagerCompensationPeriod({
    required String periodId,
  }) async {
    final Object? raw = await _client.rpc(
      'izytel_admin_approve_manager_compensation_period',
      params: <String, dynamic>{'p_period_id': periodId},
    );
    return _rpcMap(raw);
  }

  Future<Map<String, dynamic>> adjustManagerCompensationPeriod({
    required String periodId,
    required int amount,
    required String reason,
  }) async {
    final Object? raw = await _client.rpc(
      'izytel_admin_adjust_manager_compensation_period',
      params: <String, dynamic>{
        'p_period_id': periodId,
        'p_amount': amount,
        'p_reason': reason.trim(),
        'p_idempotency_key':
            'manager-adjust-$periodId-${DateTime.now().microsecondsSinceEpoch}',
      },
    );
    return _rpcMap(raw);
  }

  Future<Map<String, dynamic>> recordManagerPayout({
    required String managerId,
    required String periodId,
    required int amount,
    required String paymentChannel,
    required String paymentReference,
    String? note,
  }) async {
    final Object? raw = await _client.rpc(
      'izytel_admin_record_manager_payout',
      params: <String, dynamic>{
        'p_manager_id': managerId,
        'p_period_id': periodId,
        'p_amount': amount,
        'p_payment_channel': paymentChannel.trim(),
        'p_payment_reference': paymentReference.trim(),
        'p_note': _nullable(note),
      },
    );
    return _rpcMap(raw);
  }

  Future<TeamPerformanceSnapshot> fetchPerformance() async {
    final Object? raw = await _client.rpc('izytel_team_performance_snapshot');
    return TeamPerformanceSnapshot.fromMap(_rpcMap(raw));
  }

  Future<void> updateCabinisteZones({
    required String partnerId,
    required List<String> zoneIds,
  }) async {
    await _client.rpc(
      'izytel_admin_update_cabiniste_zones',
      params: <String, dynamic>{
        'p_partner_id': partnerId,
        'p_zone_ids': zoneIds,
      },
    );
  }

  Future<void> adjustManagerAgentCapacity({
    required String agentId,
    required String network,
    required int targetCapacity,
    String? reason,
  }) async {
    await _client.rpc(
      'izytel_manager_adjust_agent_capacity',
      params: <String, dynamic>{
        'p_agent_id': agentId,
        'p_network': network,
        'p_target_capacity': targetCapacity,
        'p_reason': reason,
      },
    );
  }


  String? _nullable(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  String _dateOnly(DateTime value) {
    final DateTime date = DateTime(value.year, value.month, value.day);
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Map<String, dynamic> _rpcMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    throw StateError('Réponse Supabase de supervision invalide.');
  }
}
