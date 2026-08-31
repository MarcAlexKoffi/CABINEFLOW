import 'dart:async';

import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:flutter/foundation.dart';

class AgentManagementViewModel extends ChangeNotifier {
  AgentManagementViewModel({required AgentRepository repository})
    : _repository = repository;

  final AgentRepository _repository;
  StreamSubscription<List<AgentDirectoryEntry>>? _agentsSub;
  StreamSubscription<List<AgentZone>>? _zonesSub;

  List<AgentDirectoryEntry> agents = const <AgentDirectoryEntry>[];
  List<AgentZone> zones = const <AgentZone>[];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';
  AgentAvailability? availabilityFilter;
  AgentNetwork? networkFilter;
  String? zoneFilter;
  bool? activeFilter;

  List<AgentDirectoryEntry> get filteredAgents {
    final String query = searchQuery.trim().toLowerCase();
    return agents
        .where((agent) {
          final AgentProfile? profile = agent.profile;
          if (query.isNotEmpty) {
            final String searchable = <String>[
              agent.name,
              agent.email,
              agent.phoneNumber,
              agent.agentCode,
            ].join(' ').toLowerCase();
            if (!searchable.contains(query)) return false;
          }
          if (availabilityFilter != null &&
              agent.availability != availabilityFilter) {
            return false;
          }
          if (networkFilter != null &&
              !(profile?.authorizedNetworks.contains(networkFilter) ?? false)) {
            return false;
          }
          if (zoneFilter != null &&
              !(profile?.zoneIds.contains(zoneFilter) ?? false)) {
            return false;
          }
          if (activeFilter != null && agent.isActive != activeFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  int get availableCount => agents
      .where(
        (agent) =>
            agent.isActive && agent.availability == AgentAvailability.available,
      )
      .length;

  int get suspendedCount => agents.where((agent) => !agent.isActive).length;

  Future<void> start() async {
    await _agentsSub?.cancel();
    await _zonesSub?.cancel();
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    _agentsSub = _repository.watchAgents().listen(
      (value) {
        agents = value;
        isLoading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (_) {
        isLoading = false;
        errorMessage = 'Impossible de charger les agents.';
        notifyListeners();
      },
    );
    _zonesSub = _repository.watchZones().listen((value) {
      zones = value;
      notifyListeners();
    });
  }

  void updateSearch(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void setAvailability(AgentAvailability? value) {
    availabilityFilter = value;
    notifyListeners();
  }

  void setNetwork(AgentNetwork? value) {
    networkFilter = value;
    notifyListeners();
  }

  void setZone(String? value) {
    zoneFilter = value;
    notifyListeners();
  }

  void setActive(bool? value) {
    activeFilter = value;
    notifyListeners();
  }

  void clearFilters() {
    availabilityFilter = null;
    networkFilter = null;
    zoneFilter = null;
    activeFilter = null;
    notifyListeners();
  }

  Future<List<StaffAccountSummary>> loadPendingAccounts() =>
      _repository.loadPendingAccounts();

  Future<void> activatePendingAccount(StaffAccountSummary account) =>
      _repository.activatePendingAccountAsAgent(account: account);

  @override
  void dispose() {
    _agentsSub?.cancel();
    _zonesSub?.cancel();
    super.dispose();
  }
}
