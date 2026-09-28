import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
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
  StreamSubscription<AgentPersonalProfile?>? _personalProfileSub;
  StreamSubscription<List<AgentZone>>? _zonesSub;
  StreamSubscription<List<AgentIssue>>? _issuesSub;

  AgentProfile? profile;
  AgentPersonalProfile? personalProfile;
  String? avatarUrl;
  List<AgentZone> zones = const <AgentZone>[];
  List<AgentIssue> issues = const <AgentIssue>[];
  bool isLoading = true;
  bool isSaving = false;
  bool _isDisposed = false;
  String? errorMessage;

  List<AgentZone> get assignedZones {
    final Set<String> ids = profile?.zoneIds.toSet() ?? const <String>{};
    return zones.where((zone) => ids.contains(zone.id)).toList(growable: false);
  }

  Future<void> start() async {
    await _profileSub?.cancel();
    await _personalProfileSub?.cancel();
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
          onError: (Object error, StackTrace stackTrace) {
            IzyTelLog.backendError(
              'AgentActivity.profile-watch',
              error,
              stackTrace: stackTrace,
            );
            isLoading = false;
            errorMessage = 'Impossible de charger ton profil agent.';
            notifyListeners();
          },
        );
    _personalProfileSub = _repository
        .watchPersonalProfile(agentId)
        .listen(
          (AgentPersonalProfile? value) {
            personalProfile = value;
            final String? path = value?.avatarStoragePath;
            if (path == null || path.trim().isEmpty) {
              avatarUrl = null;
              notifyListeners();
              return;
            }
            unawaited(_loadAvatarUrl(path));
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            IzyTelLog.backendError(
              'AgentActivity.personal-profile-watch',
              error,
              stackTrace: stackTrace,
            );
            // Le profil personnel ne doit jamais bloquer le profil opérationnel.
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


  Future<void> refresh() async {
    // Le pull-to-refresh ne redemarre plus les abonnements Realtime.
    // Redemarrer les streams obligeait a attendre leur annulation et pouvait
    // laisser le RefreshIndicator actif indefiniment sur certains appareils.
    // On effectue seulement des lectures ponctuelles bornees dans le temps ;
    // les abonnements existants restent la source temps reel.
    const Duration timeout = Duration(seconds: 6);

    Future<void> refreshProfile() async {
      try {
        final AgentProfile? value = await _repository
            .watchAgentProfile(agentId)
            .first
            .timeout(timeout);
        profile = value;
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'AgentActivity.refresh-profile',
          error,
          stackTrace: stackTrace,
        );
      }
    }

    Future<void> refreshPersonalProfile() async {
      try {
        final AgentPersonalProfile? value = await _repository
            .watchPersonalProfile(agentId)
            .first
            .timeout(timeout);
        personalProfile = value;
        final String? path = value?.avatarStoragePath;
        if (path == null || path.trim().isEmpty) {
          avatarUrl = null;
        } else {
          unawaited(_loadAvatarUrl(path));
        }
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'AgentActivity.refresh-personal-profile',
          error,
          stackTrace: stackTrace,
        );
      }
    }

    Future<void> refreshZones() async {
      try {
        zones = await _repository.watchZones().first.timeout(timeout);
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'AgentActivity.refresh-zones',
          error,
          stackTrace: stackTrace,
        );
      }
    }

    Future<void> refreshIssues() async {
      try {
        issues = await _repository
            .watchAgentIssues(agentId)
            .first
            .timeout(timeout);
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'AgentActivity.refresh-issues',
          error,
          stackTrace: stackTrace,
        );
      }
    }

    await Future.wait<void>(<Future<void>>[
      refreshProfile(),
      refreshPersonalProfile(),
      refreshZones(),
      refreshIssues(),
    ]);

    if (_isDisposed) return;
    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadAvatarUrl(String storagePath) async {
    final String? resolved = await _repository.resolvePersonalFileUrl(
      storagePath,
    );
    if (personalProfile?.avatarStoragePath != storagePath) return;
    avatarUrl = resolved;
    notifyListeners();
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
    final AgentProfile? previous = profile;
    if (previous == null) return false;

    // Mise a jour optimiste : le switch disponibilite/reseau repond
    // immediatement au toucher. Supabase confirme ensuite la valeur canonique
    // via Realtime ; en cas d'echec on restaure le profil precedent.
    profile = previous.copyWith(
      availability: update.availability,
      activeNetworks: update.activeNetworks,
      orangeCapacity: update.orangeCapacity,
      mtnCapacity: update.mtnCapacity,
      moovCapacity: update.moovCapacity,
      updatedAt: DateTime.now(),
    );
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.updateOwnOperations(agentId: agentId, update: update);
      return true;
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'AgentActivity.save',
        error,
        stackTrace: stackTrace,
      );
      profile = previous;
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
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'AgentActivity.report-issue',
        error,
        stackTrace: stackTrace,
      );
      errorMessage = 'Impossible d’envoyer le signalement.';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _profileSub?.cancel();
    _personalProfileSub?.cancel();
    _zonesSub?.cancel();
    _issuesSub?.cancel();
    super.dispose();
  }
}
