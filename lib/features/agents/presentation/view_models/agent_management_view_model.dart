import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:flutter/foundation.dart';

class AgentManagementViewModel extends ChangeNotifier {
  AgentManagementViewModel({required AgentRepository repository})
    : _repository = repository;

  static const Duration _initialLoadTimeout = Duration(seconds: 8);
  static const Duration _refreshTimeout = Duration(seconds: 6);

  final AgentRepository _repository;
  StreamSubscription<List<AgentDirectoryEntry>>? _agentsSub;
  StreamSubscription<List<AgentZone>>? _zonesSub;
  bool _isDisposed = false;

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
    await _cancelSubscriptions();
    if (_isDisposed) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final Completer<void> firstAgents = Completer<void>();

    _agentsSub = _repository.watchAgents().listen(
      (List<AgentDirectoryEntry> value) {
        if (_isDisposed) return;
        agents = value;
        isLoading = false;
        errorMessage = null;
        if (!firstAgents.isCompleted) firstAgents.complete();
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        IzyTelLog.backendError(
          'AgentManagement.agents-watch',
          error,
          stackTrace: stackTrace,
        );
        if (_isDisposed) return;
        isLoading = false;
        errorMessage = 'Impossible de charger les agents.';
        if (!firstAgents.isCompleted) firstAgents.complete();
        notifyListeners();
      },
    );

    _zonesSub = _repository.watchZones().listen(
      (List<AgentZone> value) {
        if (_isDisposed) return;
        zones = value;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        IzyTelLog.backendError(
          'AgentManagement.zones-watch',
          error,
          stackTrace: stackTrace,
        );
      },
    );

    try {
      await firstAgents.future.timeout(_initialLoadTimeout);
    } on TimeoutException catch (error, stackTrace) {
      IzyTelLog.backendError(
        'AgentManagement.initial-timeout',
        error,
        stackTrace: stackTrace,
      );
      if (_isDisposed || !isLoading) return;
      isLoading = false;
      errorMessage = agents.isEmpty
          ? 'Le chargement des agents prend trop de temps. Tire vers le bas pour réessayer.'
          : null;
      notifyListeners();
    }
  }

  /// Actualisation manuelle ponctuelle.
  ///
  /// Elle ne redémarre pas les abonnements temps réel permanents et est bornée
  /// afin qu'un RefreshIndicator ne puisse jamais tourner indéfiniment.
  Future<void> refresh() async {
    if (_isDisposed) return;
    try {
      final List<Object> values = await Future.wait<Object>(<Future<Object>>[
        _firstValue<List<AgentDirectoryEntry>>(
          _repository.watchAgents(),
          _refreshTimeout,
        ),
        _firstValue<List<AgentZone>>(
          _repository.watchZones(),
          _refreshTimeout,
        ),
      ]);
      if (_isDisposed) return;
      agents = values[0] as List<AgentDirectoryEntry>;
      zones = values[1] as List<AgentZone>;
      isLoading = false;
      errorMessage = null;
      notifyListeners();
    } on TimeoutException catch (error, stackTrace) {
      IzyTelLog.backendError(
        'AgentManagement.refresh-timeout',
        error,
        stackTrace: stackTrace,
      );
      if (_isDisposed) return;
      isLoading = false;
      if (agents.isEmpty) {
        errorMessage = 'Actualisation trop longue. Réessaie dans un instant.';
      }
      notifyListeners();
    } on Object catch (error, stackTrace) {
      IzyTelLog.backendError(
        'AgentManagement.refresh',
        error,
        stackTrace: stackTrace,
      );
      if (_isDisposed) return;
      isLoading = false;
      if (agents.isEmpty) {
        errorMessage = 'Impossible d’actualiser les agents.';
      }
      notifyListeners();
    }
  }

  Future<T> _firstValue<T>(Stream<T> stream, Duration timeout) {
    final Completer<T> completer = Completer<T>();
    StreamSubscription<T>? subscription;
    Timer? timer;

    void completeValue(T value) {
      if (completer.isCompleted) return;
      timer?.cancel();
      completer.complete(value);
      unawaited(subscription?.cancel());
    }

    void completeError(Object error, StackTrace stackTrace) {
      if (completer.isCompleted) return;
      timer?.cancel();
      completer.completeError(error, stackTrace);
      unawaited(subscription?.cancel());
    }

    subscription = stream.listen(
      completeValue,
      onError: completeError,
    );
    timer = Timer(timeout, () {
      if (completer.isCompleted) return;
      completer.completeError(
        TimeoutException('AgentManagement refresh timeout', timeout),
      );
      unawaited(subscription?.cancel());
    });

    return completer.future.whenComplete(() => timer?.cancel());
  }

  Future<void> _cancelSubscriptions() async {
    final List<Future<void>> cancellations = <Future<void>>[];
    final StreamSubscription<List<AgentDirectoryEntry>>? agentsSub = _agentsSub;
    final StreamSubscription<List<AgentZone>>? zonesSub = _zonesSub;
    _agentsSub = null;
    _zonesSub = null;
    if (agentsSub != null) cancellations.add(agentsSub.cancel());
    if (zonesSub != null) cancellations.add(zonesSub.cancel());
    if (cancellations.isEmpty) return;
    try {
      await Future.wait<void>(cancellations).timeout(const Duration(seconds: 2));
    } on Object catch (error, stackTrace) {
      IzyTelLog.backendError(
        'AgentManagement.cancel-streams',
        error,
        stackTrace: stackTrace,
      );
    }
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
    _isDisposed = true;
    unawaited(_agentsSub?.cancel());
    unawaited(_zonesSub?.cancel());
    _agentsSub = null;
    _zonesSub = null;
    super.dispose();
  }
}
