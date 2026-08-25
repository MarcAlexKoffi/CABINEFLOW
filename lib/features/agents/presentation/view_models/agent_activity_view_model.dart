import 'dart:async';

import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:flutter/foundation.dart';

class AgentActivityViewModel extends ChangeNotifier {
  AgentActivityViewModel({
    required this.agentId,
    required AgentRepository repository,
  }) : _repository = repository;

  final String agentId;
  final AgentRepository _repository;
  StreamSubscription<AgentProfile?>? _profileSub;
  StreamSubscription<List<AgentZone>>? _zonesSub;
  StreamSubscription<List<AgentIssue>>? _issuesSub;

  AgentProfile? profile;
  List<AgentZone> zones = const <AgentZone>[];
  List<AgentIssue> issues = const <AgentIssue>[];
  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  List<AgentZone> get assignedZones {
    final Set<String> ids = profile?.zoneIds.toSet() ?? const <String>{};
    return zones.where((zone) => ids.contains(zone.id)).toList(growable: false);
  }

  Future<void> start() async {
    await _profileSub?.cancel();
    await _zonesSub?.cancel();
    await _issuesSub?.cancel();
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    _profileSub = _repository
        .watchAgentProfile(agentId)
        .listen(
          (value) {
            profile = value;
            isLoading = false;
            notifyListeners();
          },
          onError: (_) {
            isLoading = false;
            errorMessage = 'Impossible de charger ton profil agent.';
            notifyListeners();
          },
        );
    _zonesSub = _repository.watchZones().listen((value) {
      zones = value;
      notifyListeners();
    });
    _issuesSub = _repository.watchAgentIssues(agentId).listen((value) {
      issues = value;
      notifyListeners();
    });
  }

  Future<bool> setAvailability(AgentAvailability value) async {
    final AgentProfile? current = profile;
    if (current == null) return false;
    return _save(
      AgentOperationalUpdate(
        availability: value,
        activeNetworks: current.activeNetworks,
        orangeCapacity: current.orangeCapacity,
        mtnCapacity: current.mtnCapacity,
        moovCapacity: current.moovCapacity,
      ),
    );
  }

  Future<bool> toggleNetwork(AgentNetwork network, bool enabled) async {
    final AgentProfile? current = profile;
    if (current == null || !current.authorizedNetworks.contains(network)) {
      return false;
    }
    final Set<AgentNetwork> active = current.activeNetworks.toSet();
    enabled ? active.add(network) : active.remove(network);
    return _save(
      AgentOperationalUpdate(
        availability: current.availability,
        activeNetworks: active.toList(growable: false),
        orangeCapacity: current.orangeCapacity,
        mtnCapacity: current.mtnCapacity,
        moovCapacity: current.moovCapacity,
      ),
    );
  }

  Future<bool> updateCapacity(AgentNetwork network, int value) async {
    final AgentProfile? current = profile;
    if (current == null || value < 0) return false;
    return _save(
      AgentOperationalUpdate(
        availability: current.availability,
        activeNetworks: current.activeNetworks,
        orangeCapacity: network == AgentNetwork.orange
            ? value
            : current.orangeCapacity,
        mtnCapacity: network == AgentNetwork.mtn ? value : current.mtnCapacity,
        moovCapacity: network == AgentNetwork.moov
            ? value
            : current.moovCapacity,
      ),
    );
  }

  Future<bool> _save(AgentOperationalUpdate update) async {
    if (isSaving) return false;
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.updateOwnOperations(agentId: agentId, update: update);
      return true;
    } catch (_) {
      errorMessage = 'Impossible d’enregistrer la modification.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> reportIssue(AgentIssueDraft issue) async {
    try {
      await _repository.createIssue(agentId: agentId, issue: issue);
      return true;
    } catch (_) {
      errorMessage = 'Impossible d’envoyer le signalement.';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _zonesSub?.cancel();
    _issuesSub?.cancel();
    super.dispose();
  }
}
