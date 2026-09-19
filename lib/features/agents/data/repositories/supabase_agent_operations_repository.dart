import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAgentOperationalRecord {
  const SupabaseAgentOperationalRecord({
    required this.agentId,
    required this.isActive,
    required this.profile,
  });

  final String agentId;
  final bool isActive;
  final AgentProfile profile;
}

/// Source canonique Phase 3 des donnees operationnelles Agent.
///
/// Firebase conserve l'identite/role du compte, mais disponibilite, reseaux,
/// capacites et quotas sont desormais portes par Supabase afin que le moteur
/// d'affectation et l'ecran Agent lisent exactement les memes valeurs.
class SupabaseAgentOperationsRepository {
  SupabaseAgentOperationsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String tableName = 'phase5_agent_capacities';
  static const Duration pollInterval = Duration(seconds: 3);

  final SupabaseClient _client;

  Future<SupabaseAgentOperationalRecord?> fetchRecord(String agentId) async {
    final String id = agentId.trim();
    if (id.isEmpty) return null;
    final Map<String, dynamic>? row = await _client
        .from(tableName)
        .select()
        .eq('agent_id', id)
        .maybeSingle();
    return row == null ? null : _recordFromRow(row);
  }

  Future<List<SupabaseAgentOperationalRecord>> fetchAllForStaff() async {
    final List<Map<String, dynamic>> rows = await _client
        .from(tableName)
        .select()
        .order('agent_name');
    return List<SupabaseAgentOperationalRecord>.unmodifiable(
      rows.map(_recordFromRow),
    );
  }

  Stream<AgentProfile?> watchProfile(String agentId) async* {
    AgentProfile? lastKnown;
    int failures = 0;
    while (true) {
      try {
        final SupabaseAgentOperationalRecord? record = await fetchRecord(
          agentId,
        );
        lastKnown = record?.profile;
        failures = 0;
        yield lastKnown;
        await Future<void>.delayed(pollInterval);
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'AgentOperations.profile',
          error,
          stackTrace: stackTrace,
        );
        if (!BackendFailurePolicy.canRetryRead(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        if (lastKnown != null) yield lastKnown;
        await Future<void>.delayed(
          BackendFailurePolicy.retryDelay(
            baseDelay: pollInterval,
            consecutiveFailures: failures++,
          ),
        );
      }
    }
  }

  Stream<List<SupabaseAgentOperationalRecord>> watchAllForStaff() async* {
    List<SupabaseAgentOperationalRecord>? lastKnown;
    int failures = 0;
    while (true) {
      try {
        lastKnown = await fetchAllForStaff();
        failures = 0;
        yield lastKnown;
        await Future<void>.delayed(pollInterval);
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'AgentOperations.directory',
          error,
          stackTrace: stackTrace,
        );
        if (!BackendFailurePolicy.canRetryRead(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        if (lastKnown != null) yield lastKnown;
        await Future<void>.delayed(
          BackendFailurePolicy.retryDelay(
            baseDelay: pollInterval,
            consecutiveFailures: failures++,
          ),
        );
      }
    }
  }

  Future<AgentProfile> updateOwnOperations({
    required String agentId,
    required AgentOperationalUpdate update,
  }) async {
    final String uid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (uid.isEmpty || uid != agentId.trim()) {
      throw StateError('La session Agent ne correspond pas au profil a modifier.');
    }
    final Object? raw = await _client.rpc(
      'phase3_update_own_agent_operations',
      params: <String, dynamic>{
        'p_availability': update.availability.name,
        'p_active_networks': update.activeNetworks
            .map((AgentNetwork network) => network.name)
            .toList(growable: false),
        'p_orange': update.orangeCapacity,
        'p_mtn': update.mtnCapacity,
        'p_moov': update.moovCapacity,
      },
    );
    return _profileFromRpc(raw, fallbackAgentId: agentId);
  }

  Future<AgentProfile> updateAgentAdmin({
    required AgentDirectoryEntry agent,
    required AgentAdminUpdate update,
  }) async {
    final AgentProfile current = agent.profile ?? _defaultProfile(agent.userId);
    final List<AgentNetwork> activeNetworks = current.activeNetworks
        .where(update.authorizedNetworks.contains)
        .toList(growable: false);

    final Object? raw = await _client.rpc(
      'phase3_admin_update_agent_operations',
      params: <String, dynamic>{
        'p_agent_id': agent.userId.trim(),
        'p_agent_name': update.name.trim(),
        'p_is_active': update.isActive,
        'p_zone_ids': update.zoneIds,
        'p_authorized_networks': update.authorizedNetworks
            .map((AgentNetwork network) => network.name)
            .toList(growable: false),
        'p_active_networks': update.isActive
            ? activeNetworks
                  .map((AgentNetwork network) => network.name)
                  .toList(growable: false)
            : <String>[],
        'p_daily_transaction_limit': update.dailyTransactionLimit,
        'p_max_transactions_per_day': update.maxTransactionsPerDay,
        'p_orange': update.orangeCapacity,
        'p_mtn': update.mtnCapacity,
        'p_moov': update.moovCapacity,
      },
    );
    return _profileFromRpc(raw, fallbackAgentId: agent.userId);
  }

  Future<void> adjustManagerCapacity({
    required String agentId,
    required AgentNetwork network,
    required int targetCapacity,
    String? reason,
  }) async {
    final String uid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (uid.isEmpty) {
      throw StateError('Aucune session Manager active.');
    }
    await _client.rpc(
      'izytel_manager_adjust_agent_capacity',
      params: <String, dynamic>{
        'p_agent_id': agentId.trim(),
        'p_network': network.name,
        'p_target_capacity': targetCapacity,
        'p_reason': reason?.trim().isEmpty ?? true ? null : reason!.trim(),
      },
    );
  }

  Future<AgentProfile> provisionAgent({
    required StaffAccountSummary account,
  }) async {
    final AgentDirectoryEntry entry = AgentDirectoryEntry(
      userId: account.userId,
      name: account.name,
      email: account.email,
      phoneNumber: account.phoneNumber,
      isActive: true,
      profile: _defaultProfile(account.userId),
    );
    return updateAgentAdmin(
      agent: entry,
      update: AgentAdminUpdate(
        name: account.name,
        phoneNumber: account.phoneNumber,
        isActive: true,
        zoneIds: const <String>[],
        authorizedNetworks: const <AgentNetwork>[],
        orangeCapacity: 0,
        mtnCapacity: 0,
        moovCapacity: 0,
        dailyTransactionLimit: 500000,
        maxTransactionsPerDay: 150,
      ),
    );
  }

  SupabaseAgentOperationalRecord _recordFromRow(Map<String, dynamic> row) {
    final String id = _string(row['agent_id']);
    if (id.isEmpty) {
      throw StateError('Profil operationnel Agent Supabase invalide.');
    }
    return SupabaseAgentOperationalRecord(
      agentId: id,
      isActive: row['is_active'] == true,
      profile: _profileFromRow(row, fallbackAgentId: id),
    );
  }

  AgentProfile _profileFromRpc(Object? raw, {required String fallbackAgentId}) {
    final Map<String, dynamic>? row = raw is Map<String, dynamic>
        ? raw
        : raw is Map
        ? Map<String, dynamic>.from(raw)
        : null;
    if (row == null) {
      throw StateError('Reponse operationnelle Agent Supabase invalide.');
    }
    return _profileFromRow(row, fallbackAgentId: fallbackAgentId);
  }

  AgentProfile _profileFromRow(
    Map<String, dynamic> row, {
    required String fallbackAgentId,
  }) {
    final String userId = _string(row['agent_id'], fallback: fallbackAgentId);
    return AgentProfile(
      userId: userId,
      agentCode: _string(row['agent_code'], fallback: _agentCode(userId)),
      availability: _string(row['availability']) == 'available'
          ? AgentAvailability.available
          : AgentAvailability.unavailable,
      zoneIds: _stringList(row['zone_ids']),
      authorizedNetworks: _networkList(row['authorized_networks']),
      activeNetworks: _networkList(row['active_networks']),
      orangeCapacity: _int(row['orange_capacity']),
      mtnCapacity: _int(row['mtn_capacity']),
      moovCapacity: _int(row['moov_capacity']),
      dailyTransactionLimit: _int(row['daily_transaction_limit']),
      maxTransactionsPerDay: _int(row['max_transactions_per_day']),
      lastCapacityUpdateAt: _date(row['updated_at']),
      lastSeenAt: _date(row['last_seen_at']),
      createdAt: _date(row['created_at']),
      updatedAt: _date(row['updated_at']),
    );
  }

  AgentProfile _defaultProfile(String userId) {
    return AgentProfile(
      userId: userId,
      agentCode: _agentCode(userId),
      availability: AgentAvailability.unavailable,
      zoneIds: const <String>[],
      authorizedNetworks: const <AgentNetwork>[],
      activeNetworks: const <AgentNetwork>[],
      orangeCapacity: 0,
      mtnCapacity: 0,
      moovCapacity: 0,
      dailyTransactionLimit: 500000,
      maxTransactionsPerDay: 150,
    );
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<String>()
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  List<AgentNetwork> _networkList(Object? value) {
    if (value is! List) return const <AgentNetwork>[];
    final Set<AgentNetwork> result = <AgentNetwork>{};
    for (final Object? item in value) {
      final String token = _string(item).toLowerCase();
      for (final AgentNetwork network in AgentNetwork.values) {
        if (network.name == token) result.add(network);
      }
    }
    return result.toList(growable: false);
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim())?.toLocal();
    }
    return null;
  }

  String _string(Object? value, {String fallback = ''}) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _agentCode(String uid) {
    final String compact = uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final String suffix = compact.length <= 6
        ? compact.toUpperCase()
        : compact.substring(0, 6).toUpperCase();
    return 'AG-$suffix';
  }
}
