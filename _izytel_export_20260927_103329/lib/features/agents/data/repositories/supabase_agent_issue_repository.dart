import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAgentIssueRepository {
  SupabaseAgentIssueRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String tableName = 'agent_issues';

  // Temporaire pendant la phase hybride Firebase Auth -> Supabase.
  // La Data API Supabase est stable avec le JWT Firebase, alors que le canal
  // Realtime peut se fermer apres la premiere lecture. Un polling leger garde
  // les ecrans Agent/Admin synchronises sans faire disparaitre les donnees.
  static const Duration _pollInterval = Duration(seconds: 4);

  final SupabaseClient _client;

  Stream<List<AgentIssue>> watchAgentIssues(String agentId) {
    final String cleanAgentId = agentId.trim();
    if (cleanAgentId.isEmpty) {
      return Stream<List<AgentIssue>>.value(const <AgentIssue>[]);
    }

    return _watchIssues(agentId: cleanAgentId);
  }

  Stream<List<AgentIssue>> watchAllAgentIssues() {
    return _watchIssues();
  }

  Stream<List<AgentIssue>> _watchIssues({String? agentId}) async* {
    List<AgentIssue>? lastSuccessful;
    int consecutiveFailures = 0;

    while (true) {
      try {
        final List<Map<String, dynamic>> rows = agentId == null
            ? await _client.from(tableName).select()
            : await _client.from(tableName).select().eq('agent_id', agentId);

        final List<AgentIssue> issues = _issuesFromRows(rows);
        lastSuccessful = issues;
        consecutiveFailures = 0;
        yield issues;
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'SupabaseAgentIssues.watch',
          error,
          stackTrace: stackTrace,
        );

        if (!BackendFailurePolicy.canRetryRead(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }

        // Une panne reseau transitoire ne ferme plus le stream. Si une valeur
        // fiable existe deja, elle reste affichee jusqu'a la reconnexion.
        consecutiveFailures += 1;
        if (lastSuccessful != null) {
          yield lastSuccessful;
        }
      }

      await Future<void>.delayed(
        BackendFailurePolicy.retryDelay(
          baseDelay: _pollInterval,
          consecutiveFailures: consecutiveFailures,
        ),
      );
    }
  }

  Future<void> createIssue({
    required String agentId,
    required AgentIssueDraft issue,
  }) async {
    final String uid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    final String cleanAgentId = agentId.trim();
    if (uid.isEmpty || uid != cleanAgentId) {
      throw StateError(
        'La session Firebase ne correspond pas \u00e0 l\u2019Agent qui signale le probl\u00e8me.',
      );
    }

    final String description = issue.description.trim();
    if (description.length < 3 || description.length > 1000) {
      throw StateError(
        'La description doit contenir entre 3 et 1000 caract\u00e8res.',
      );
    }

    await _client.from(tableName).insert(<String, dynamic>{
      'agent_id': uid,
      'type': issue.type.trim(),
      'network': issue.network?.name,
      'description': description,
      'status': 'open',
    });
  }

  Future<void> updateIssueStatus({
    required String issueId,
    required String status,
    String? resolvedBy,
  }) async {
    final String uid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (uid.isEmpty) {
      throw StateError('Aucune session Firebase active.');
    }

    final String cleanStatus = status.trim();
    if (!const <String>{
      'in_progress',
      'resolved',
      'cancelled',
    }.contains(cleanStatus)) {
      throw StateError('Statut de signalement non autoris\u00e9.');
    }

    final bool closesIssue =
        cleanStatus == 'resolved' || cleanStatus == 'cancelled';
    await _client
        .from(tableName)
        .update(<String, dynamic>{
          'status': cleanStatus,
          'resolved_by': closesIssue ? resolvedBy?.trim() : null,
        })
        .eq('id', issueId.trim());
  }

  List<AgentIssue> _issuesFromRows(List<Map<String, dynamic>> rows) {
    final List<AgentIssue> issues =
        rows.map(_issueFromRow).whereType<AgentIssue>().toList(growable: false)
          ..sort(
            (AgentIssue a, AgentIssue b) => b.createdAt.compareTo(a.createdAt),
          );
    return List<AgentIssue>.unmodifiable(issues);
  }

  AgentIssue? _issueFromRow(Map<String, dynamic> row) {
    final DateTime? createdAt = _date(row['created_at']);
    final String id = _string(row['id']);
    final String agentId = _string(row['agent_id']);
    final String description = _string(row['description']);
    if (createdAt == null ||
        id.isEmpty ||
        agentId.isEmpty ||
        description.isEmpty) {
      return null;
    }

    return AgentIssue(
      id: id,
      agentId: agentId,
      type: _string(row['type']),
      network: _network(row['network']),
      description: description,
      status: _string(row['status'], fallback: 'open'),
      createdAt: createdAt,
      updatedAt: _date(row['updated_at']),
      resolvedAt: _date(row['resolved_at']),
      resolvedBy: _nullableString(row['resolved_by']),
    );
  }

  AgentNetwork? _network(Object? value) {
    final String raw = _string(value).toLowerCase();
    for (final AgentNetwork network in AgentNetwork.values) {
      if (network.name == raw) return network;
    }
    return null;
  }

  String _string(Object? value, {String fallback = ''}) {
    if (value is! String) return fallback;
    final String text = value.trim();
    return text.isEmpty ? fallback : text;
  }

  String? _nullableString(Object? value) {
    final String text = _string(value);
    return text.isEmpty ? null : text;
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim())?.toLocal();
    }
    return null;
  }
}
