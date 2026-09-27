import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_issue_center_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAgentIssueCenterRepository {
  SupabaseAgentIssueCenterRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const Duration _pollInterval = Duration(seconds: 4);

  final SupabaseClient _client;

  Stream<AgentIssueCenterSnapshot> watchSnapshot() async* {
    AgentIssueCenterSnapshot? lastSuccessful;
    int consecutiveFailures = 0;

    while (true) {
      try {
        final AgentIssueCenterSnapshot snapshot = await fetchSnapshot();
        lastSuccessful = snapshot;
        consecutiveFailures = 0;
        yield snapshot;
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'SupabaseAgentIssueCenter.watchSnapshot',
          error,
          stackTrace: stackTrace,
        );
        if (!BackendFailurePolicy.canRetryRead(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        consecutiveFailures += 1;
        if (lastSuccessful != null) yield lastSuccessful;
      }

      await Future<void>.delayed(
        BackendFailurePolicy.retryDelay(
          baseDelay: _pollInterval,
          consecutiveFailures: consecutiveFailures,
        ),
      );
    }
  }

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
