import 'dart:async';

import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';

class FakeAgentRepository implements AgentRepository {
  FakeAgentRepository() {
    _zones = <AgentZone>[
      const AgentZone(
        id: 'zone-cocody',
        name: 'Cocody',
        city: 'Abidjan',
        region: 'Abidjan',
        isActive: true,
      ),
      const AgentZone(
        id: 'zone-plateau',
        name: 'Plateau',
        city: 'Abidjan',
        region: 'Abidjan',
        isActive: true,
      ),
    ];
    _agents = <AgentDirectoryEntry>[
      AgentDirectoryEntry(
        userId: 'AGENT-001',
        name: 'Koffi Kouassi',
        email: 'agent@cabineflow.app',
        phoneNumber: '0700000001',
        isActive: true,
        profile: const AgentProfile(
          userId: 'AGENT-001',
          agentCode: 'AG-0001',
          availability: AgentAvailability.available,
          zoneIds: <String>['zone-cocody'],
          authorizedNetworks: <AgentNetwork>[
            AgentNetwork.orange,
            AgentNetwork.mtn,
          ],
          activeNetworks: <AgentNetwork>[AgentNetwork.orange, AgentNetwork.mtn],
          orangeCapacity: 35000,
          mtnCapacity: 18000,
          moovCapacity: 0,
          dailyTransactionLimit: 500000,
          maxTransactionsPerDay: 150,
        ),
      ),
    ];
  }

  late List<AgentDirectoryEntry> _agents;
  late List<AgentZone> _zones;
  final Map<String, List<AgentIssue>> _issues = <String, List<AgentIssue>>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void _notify() => _changes.add(null);

  @override
  Stream<List<AgentDirectoryEntry>> watchAgents() async* {
    yield List<AgentDirectoryEntry>.unmodifiable(_agents);
    await for (final _ in _changes.stream) {
      yield List<AgentDirectoryEntry>.unmodifiable(_agents);
    }
  }

  @override
  Stream<AgentProfile?> watchAgentProfile(String agentId) async* {
    AgentProfile? current() {
      for (final AgentDirectoryEntry agent in _agents) {
        if (agent.userId == agentId) return agent.profile;
      }
      return null;
    }

    yield current();
    await for (final _ in _changes.stream) {
      yield current();
    }
  }

  @override
  Stream<List<AgentZone>> watchZones() async* {
    yield List<AgentZone>.unmodifiable(_zones);
    await for (final _ in _changes.stream) {
      yield List<AgentZone>.unmodifiable(_zones);
    }
  }

  @override
  Stream<List<AgentIssue>> watchAgentIssues(String agentId) async* {
    List<AgentIssue> current() =>
        List<AgentIssue>.unmodifiable(_issues[agentId] ?? const <AgentIssue>[]);
    yield current();
    await for (final _ in _changes.stream) {
      yield current();
    }
  }

  @override
  Future<List<StaffAccountSummary>> loadPendingAccounts() async {
    return const <StaffAccountSummary>[
      StaffAccountSummary(
        userId: 'PENDING-001',
        name: 'Awa N’Diaye',
        email: 'awa@cabineflow.app',
        phoneNumber: '0700000002',
        role: 'pending',
        isActive: false,
      ),
    ];
  }

  @override
  Future<void> activatePendingAccountAsAgent({
    required StaffAccountSummary account,
  }) async {
    _agents = <AgentDirectoryEntry>[
      ..._agents,
      AgentDirectoryEntry(
        userId: account.userId,
        name: account.name,
        email: account.email,
        phoneNumber: account.phoneNumber,
        isActive: true,
        profile: AgentProfile(
          userId: account.userId,
          agentCode: 'AG-${_shortCode(account.userId)}',
          availability: AgentAvailability.unavailable,
          zoneIds: const <String>[],
          authorizedNetworks: const <AgentNetwork>[],
          activeNetworks: const <AgentNetwork>[],
          orangeCapacity: 0,
          mtnCapacity: 0,
          moovCapacity: 0,
          dailyTransactionLimit: 500000,
          maxTransactionsPerDay: 150,
        ),
      ),
    ];
    _notify();
  }

  @override
  Future<void> saveAgentAdmin({
    required AgentDirectoryEntry agent,
    required AgentAdminUpdate update,
  }) async {
    final AgentProfile base =
        agent.profile ??
        AgentProfile(
          userId: agent.userId,
          agentCode:
              'AG-${agent.userId.substring(0, agent.userId.length < 6 ? agent.userId.length : 6)}',
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
    final List<AgentNetwork> active = base.activeNetworks
        .where(update.authorizedNetworks.contains)
        .toList(growable: false);
    _agents = _agents
        .map((entry) {
          if (entry.userId != agent.userId) return entry;
          return AgentDirectoryEntry(
            userId: entry.userId,
            name: update.name,
            email: entry.email,
            phoneNumber: update.phoneNumber,
            isActive: update.isActive,
            profile: base.copyWith(
              availability: update.isActive
                  ? base.availability
                  : AgentAvailability.unavailable,
              zoneIds: update.zoneIds,
              authorizedNetworks: update.authorizedNetworks,
              activeNetworks: update.isActive ? active : const <AgentNetwork>[],
              orangeCapacity: update.orangeCapacity,
              mtnCapacity: update.mtnCapacity,
              moovCapacity: update.moovCapacity,
              dailyTransactionLimit: update.dailyTransactionLimit,
              maxTransactionsPerDay: update.maxTransactionsPerDay,
            ),
          );
        })
        .toList(growable: false);
    _notify();
  }

  @override
  Future<void> updateOwnOperations({
    required String agentId,
    required AgentOperationalUpdate update,
  }) async {
    _agents = _agents
        .map((entry) {
          if (entry.userId != agentId || entry.profile == null) return entry;
          final AgentProfile profile = entry.profile!;
          return AgentDirectoryEntry(
            userId: entry.userId,
            name: entry.name,
            email: entry.email,
            phoneNumber: entry.phoneNumber,
            isActive: entry.isActive,
            profile: profile.copyWith(
              availability: update.availability,
              activeNetworks: update.activeNetworks
                  .where(profile.authorizedNetworks.contains)
                  .toList(growable: false),
              orangeCapacity: update.orangeCapacity,
              mtnCapacity: update.mtnCapacity,
              moovCapacity: update.moovCapacity,
              lastCapacityUpdateAt: DateTime.now(),
              lastSeenAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        })
        .toList(growable: false);
    _notify();
  }

  @override
  Future<String> createZone({
    required String name,
    required String city,
    required String region,
  }) async {
    final String id = 'zone-${_zones.length + 1}';
    _zones = <AgentZone>[
      ..._zones,
      AgentZone(id: id, name: name, city: city, region: region, isActive: true),
    ];
    _notify();
    return id;
  }

  @override
  Future<void> createIssue({
    required String agentId,
    required AgentIssueDraft issue,
  }) async {
    final List<AgentIssue> current = _issues[agentId] ?? <AgentIssue>[];
    _issues[agentId] = <AgentIssue>[
      AgentIssue(
        id: 'ISS-${current.length + 1}',
        agentId: agentId,
        type: issue.type,
        network: issue.network,
        description: issue.description,
        status: 'open',
        createdAt: DateTime.now(),
      ),
      ...current,
    ];
    _notify();
  }

  String _shortCode(String value) {
    final String compact = value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (compact.isEmpty) return 'TEST';
    return (compact.length <= 6 ? compact : compact.substring(0, 6))
        .toUpperCase();
  }
}
