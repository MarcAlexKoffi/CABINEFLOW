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
    return TeamMemberDetail.fromMap(_rpcMap(raw));
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

  Map<String, dynamic> _rpcMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    throw StateError('Réponse Supabase de supervision invalide.');
  }
}
