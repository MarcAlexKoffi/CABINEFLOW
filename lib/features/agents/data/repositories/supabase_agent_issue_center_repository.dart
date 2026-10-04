import 'package:cabine_flow/core/supabase/supabase_realtime_refetch.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_issue_center_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAgentIssueCenterRepository {
  SupabaseAgentIssueCenterRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<AgentIssueCenterSnapshot> watchSnapshot() =>
      SupabaseRealtimeRefetch.watch<AgentIssueCenterSnapshot>(
        client: _client,
        fetch: fetchSnapshot,
        label: 'SupabaseAgentIssueCenter.watchSnapshot',
        signals: const <SupabaseRealtimeSignal>[
          SupabaseRealtimeSignal(
            table: 'agent_issues',
            primaryKey: <String>['id'],
          ),
        ],
      );

  Future<AgentIssueCenterSnapshot> fetchSnapshot() async {
    final dynamic response = await _client.rpc(
      'izytel_bo72_agent_issue_center_snapshot',
    );
    if (response is! Map) {
      throw StateError('Le centre de signalements Supabase est invalide.');
    }
    return AgentIssueCenterSnapshot.fromJson(
      response.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
    );
  }

  Future<void> transitionIssue({
    required String issueId,
    required String status,
    String? note,
  }) async {
    final String cleanId = issueId.trim();
    final String cleanStatus = status.trim();
    if (cleanId.isEmpty) {
      throw StateError('Identifiant de signalement invalide.');
    }
    if (!const <String>{'in_progress', 'resolved', 'cancelled'}
        .contains(cleanStatus)) {
      throw StateError('Statut de signalement non autorisé.');
    }

    await _client.rpc(
      'izytel_bo72_transition_agent_issue',
      params: <String, dynamic>{
        'p_issue_id': cleanId,
        'p_status': cleanStatus,
        'p_note': note?.trim(),
      },
    );
  }
}
