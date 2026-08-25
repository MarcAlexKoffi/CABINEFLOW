import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:flutter/foundation.dart';

class AgentDetailViewModel extends ChangeNotifier {
  AgentDetailViewModel({
    required this.agent,
    required AgentRepository repository,
    required List<AgentZone> zones,
  }) : _repository = repository,
       zones = zones {
    final AgentProfile? profile = agent.profile;
    name = agent.name;
    phoneNumber = agent.phoneNumber;
    isActive = agent.isActive;
    zoneIds = <String>{...?profile?.zoneIds};
    authorizedNetworks = <AgentNetwork>{...?profile?.authorizedNetworks};
    orangeCapacity = profile?.orangeCapacity ?? 0;
    mtnCapacity = profile?.mtnCapacity ?? 0;
    moovCapacity = profile?.moovCapacity ?? 0;
    dailyTransactionLimit = profile?.dailyTransactionLimit ?? 500000;
    maxTransactionsPerDay = profile?.maxTransactionsPerDay ?? 150;
  }

  final AgentDirectoryEntry agent;
  final AgentRepository _repository;
  final List<AgentZone> zones;

  late String name;
  late String phoneNumber;
  late bool isActive;
  late Set<String> zoneIds;
  late Set<AgentNetwork> authorizedNetworks;
  late int orangeCapacity;
  late int mtnCapacity;
  late int moovCapacity;
  late int dailyTransactionLimit;
  late int maxTransactionsPerDay;
  bool isSaving = false;
  String? errorMessage;

  void setName(String value) => name = value;
  void setPhone(String value) => phoneNumber = value;

  void setActive(bool value) {
    isActive = value;
    notifyListeners();
  }

  void toggleZone(String zoneId) {
    zoneIds.contains(zoneId) ? zoneIds.remove(zoneId) : zoneIds.add(zoneId);
    notifyListeners();
  }

  void toggleNetwork(AgentNetwork network) {
    authorizedNetworks.contains(network)
        ? authorizedNetworks.remove(network)
        : authorizedNetworks.add(network);
    notifyListeners();
  }

  void setLimits({required int amount, required int count}) {
    dailyTransactionLimit = amount;
    maxTransactionsPerDay = count;
  }

  void setCapacity(AgentNetwork network, int value) {
    switch (network) {
      case AgentNetwork.orange:
        orangeCapacity = value;
        return;
      case AgentNetwork.mtn:
        mtnCapacity = value;
        return;
      case AgentNetwork.moov:
        moovCapacity = value;
        return;
    }
  }

  Future<String?> createZone({
    required String name,
    required String city,
    required String region,
  }) async {
    try {
      return await _repository.createZone(
        name: name,
        city: city,
        region: region,
      );
    } catch (_) {
      errorMessage = 'Impossible de créer la zone.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> save() async {
    if (isSaving) return false;
    final String normalizedName = name.trim();
    if (normalizedName.length < 2) {
      errorMessage = 'Le nom de l’agent est trop court.';
      notifyListeners();
      return false;
    }
    if (dailyTransactionLimit < 0 ||
        maxTransactionsPerDay < 0 ||
        orangeCapacity < 0 ||
        mtnCapacity < 0 ||
        moovCapacity < 0) {
      errorMessage = 'Les limites et capacités doivent être positives.';
      notifyListeners();
      return false;
    }
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.saveAgentAdmin(
        agent: agent,
        update: AgentAdminUpdate(
          name: normalizedName,
          phoneNumber: phoneNumber.trim(),
          isActive: isActive,
          zoneIds: zoneIds.toList(growable: false),
          authorizedNetworks: authorizedNetworks.toList(growable: false),
          orangeCapacity: orangeCapacity,
          mtnCapacity: mtnCapacity,
          moovCapacity: moovCapacity,
          dailyTransactionLimit: dailyTransactionLimit,
          maxTransactionsPerDay: maxTransactionsPerDay,
        ),
      );
      return true;
    } catch (_) {
      errorMessage = 'Impossible d’enregistrer le profil agent.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
