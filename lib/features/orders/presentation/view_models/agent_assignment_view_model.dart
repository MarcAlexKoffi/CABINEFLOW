import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AgentAssignmentCandidate {
  const AgentAssignmentCandidate({
    required this.agent,
    required this.zones,
    required this.activeAssignments,
    required this.capacity,
    required this.isAssignable,
    required this.unavailableReason,
    required this.isCurrentAssignment,
  });

  final AgentDirectoryEntry agent;
  final List<AgentZone> zones;
  final int activeAssignments;
  final int capacity;
  final bool isAssignable;
  final String? unavailableReason;
  final bool isCurrentAssignment;
}

class AgentAssignmentViewModel extends ChangeNotifier {
  AgentAssignmentViewModel({
    required this.order,
    required this.adminUserId,
    required this.isManager,
    required this.agentRepository,
    required this.ordersRepository,
  });

  QueueOrder order;
  final String adminUserId;
  final bool isManager;
  final AgentRepository agentRepository;
  final OrdersRepository ordersRepository;

  StreamSubscription<List<AgentDirectoryEntry>>? _agentsSubscription;
  StreamSubscription<List<AgentZone>>? _zonesSubscription;
  StreamSubscription<Map<String, int>>? _assignmentCountsSubscription;

  List<AgentDirectoryEntry> _agents = const <AgentDirectoryEntry>[];
  List<AgentZone> _zones = const <AgentZone>[];
  Map<String, int> _activeAssignmentCounts = const <String, int>{};
  Map<String, int> _reservedAmounts = const <String, int>{};
  String? _assigningAgentId;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isDisposed = false;
  bool _canonicalStateVerified = true;
  bool _reservedRefreshInFlight = false;
  bool _reservedRefreshPending = false;
  bool _refreshInFlight = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get assigningAgentId => _assigningAgentId;

  bool get canAssignCanonically =>
      _canonicalStateVerified && hasCanonicalOrderZone;

  List<AgentAssignmentCandidate> get candidates {
    // Fail closed for both Admin and Manager. A manual assignment without the
    // canonical Phase 4 zone could send a Yakro order to an Abidjan agent.
    if (!canAssignCanonically) {
      return const <AgentAssignmentCandidate>[];
    }
    final AgentNetwork requiredNetwork = _agentNetwork(order.network);
    final List<AgentAssignmentCandidate> result = <AgentAssignmentCandidate>[];

    for (final AgentDirectoryEntry agent in _agents) {
      final AgentProfile? profile = agent.profile;
      if (profile == null ||
          !profile.authorizedNetworks.contains(requiredNetwork)) {
        continue;
      }

      final int declaredCapacity = profile.capacityFor(requiredNetwork);
      final int reserved = _reservedAmounts[agent.userId] ?? 0;
      final int capacity = (declaredCapacity - reserved)
          .clamp(0, declaredCapacity)
          .toInt();
      final bool orderAlreadyAssigned = order.isAssignedToAgent;
      final bool isCurrent =
          orderAlreadyAssigned && order.assignedAgentId == agent.userId;
      String? reason;

      // Une page ouverte depuis un etat Firebase obsolete peut apprendre, au
      // rafraichissement Supabase, que la commande est deja affectee. Dans ce
      // cas aucun bouton ne doit permettre une seconde affectation implicite.
      if (orderAlreadyAssigned) {
        reason = isCurrent ? 'Déjà affecté' : 'Commande déjà affectée';
      } else if (!agent.isActive) {
        reason = 'Agent suspendu';
      } else if (profile.availability != AgentAvailability.available) {
        reason = 'Indisponible';
      } else if (!profile.activeNetworks.contains(requiredNetwork)) {
        reason = 'Réseau désactivé';
      } else if (hasCanonicalOrderZone &&
          !profile.zoneIds.contains(order.zoneId!.trim())) {
        reason = 'Hors zone de la commande';
      } else if (capacity < order.amount) {
        reason = 'Capacité insuffisante';
      }

      final List<AgentZone> zones = _zones
          .where((AgentZone zone) => profile.zoneIds.contains(zone.id))
          .toList(growable: false);

      result.add(
        AgentAssignmentCandidate(
          agent: agent,
          zones: zones,
          activeAssignments: _activeAssignmentCounts[agent.userId] ?? 0,
          capacity: capacity,
          isAssignable: reason == null,
          unavailableReason: reason,
          isCurrentAssignment: isCurrent,
        ),
      );
    }

    result.sort((AgentAssignmentCandidate a, AgentAssignmentCandidate b) {
      if (a.isAssignable != b.isAssignable) {
        return a.isAssignable ? -1 : 1;
      }
      final int load = a.activeAssignments.compareTo(b.activeAssignments);
      if (load != 0) return load;
      final int capacity = b.capacity.compareTo(a.capacity);
      if (capacity != 0) return capacity;
      return a.agent.name.toLowerCase().compareTo(b.agent.name.toLowerCase());
    });

    return List<AgentAssignmentCandidate>.unmodifiable(result);
  }

  int get assignableCount =>
      candidates.where((item) => item.isAssignable).length;

  String get orderZoneLabel {
    final String zoneId = order.zoneId?.trim() ?? '';
    if (zoneId.isEmpty) {
      return 'Zone non disponible';
    }

    for (final AgentZone zone in _zones) {
      if (zone.id == zoneId) return zone.displayLabel;
    }

    // La zone canonique vient de Supabase. Si le flux des libelles de zones
    // tarde a arriver, on evite d'afficher a tort « non renseignee ».
    return 'Zone affectee';
  }

  bool get hasCanonicalOrderZone => (order.zoneId?.trim().isNotEmpty ?? false);

  Future<void> start() async {
    _errorMessage = null;
    _isLoading = true;
    _canonicalStateVerified = false;
    notifyListeners();

    // Toujours recharger la ligne Phase 4 avant de proposer une affectation.
    // Firestore peut encore contenir une commande payée qui n'a pas fini sa
    // synchronisation Supabase ; dans ce cas l'Admin comme le Manager doivent
    // être bloqués plutôt que de voir tous les Agents comme compatibles.
    await _refreshCanonicalOrder();

    await _agentsSubscription?.cancel();
    await _zonesSubscription?.cancel();
    await _assignmentCountsSubscription?.cancel();

    _agentsSubscription = agentRepository.watchAgents().listen(
      (List<AgentDirectoryEntry> agents) {
        _agents = agents;
        _isLoading = false;
        notifyListeners();
        unawaited(_refreshReservedAmounts());
      },
      onError: (_) {
        _errorMessage = 'Impossible de charger les agents.';
        _isLoading = false;
        notifyListeners();
      },
    );

    _zonesSubscription = agentRepository.watchZones().listen(
      (List<AgentZone> zones) {
        _zones = zones
            .where((AgentZone zone) => zone.isActive)
            .toList(growable: false);
        notifyListeners();
      },
      onError: (_) {
        _errorMessage = 'Impossible de charger les zones.';
        notifyListeners();
      },
    );

    _assignmentCountsSubscription = ordersRepository
        .watchActiveAssignmentCounts()
        .listen(
          (Map<String, int> counts) {
            _activeAssignmentCounts = counts;
            notifyListeners();
            unawaited(_refreshReservedAmounts());
          },
          onError: (_) {
            _activeAssignmentCounts = const <String, int>{};
            notifyListeners();
          },
        );
  }

  Future<void> refresh() async {
    if (_refreshInFlight || _isDisposed) return;
    _refreshInFlight = true;
    _errorMessage = null;
    notifyListeners();
    try {
      // Ne jamais annuler/recréer les streams lors d'un pull-to-refresh. Les
      // streams de comptage sont des boucles de polling et leur cancel peut
      // attendre un délai de retry, ce qui maintenait le RefreshIndicator à
      // l'écran pendant de longues secondes.
      await _refreshCanonicalOrder();
      await _refreshReservedAmounts();
    } finally {
      _refreshInFlight = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> _refreshCanonicalOrder() async {
    final Object repository = ordersRepository;
    if (repository is! OrderHistoryRepository) {
      _canonicalStateVerified = hasCanonicalOrderZone;
      if (!_canonicalStateVerified) {
        _errorMessage =
            'La zone canonique de cette commande n’est pas encore disponible. '             'L’affectation reste bloquée jusqu’à la synchronisation Supabase.';
      }
      return;
    }

    try {
      order = await repository.fetchOrderById(orderId: order.id);
      _canonicalStateVerified = hasCanonicalOrderZone;
      if (!_canonicalStateVerified) {
        _errorMessage =
            'La commande est encore visible dans la file historique, mais sa '             'zone Phase 4 n’est pas encore synchronisée. Actualise dans '             'quelques secondes avant toute affectation.';
      }
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'AgentAssignment.refresh-order',
        error,
        stackTrace: stackTrace,
      );
      _canonicalStateVerified = false;
      _errorMessage = _friendlyError(error);
    }
  }

  Future<void> _refreshReservedAmounts() async {
    if (_reservedRefreshInFlight) {
      _reservedRefreshPending = true;
      return;
    }
    _reservedRefreshInFlight = true;
    _reservedRefreshPending = false;
    try {
      final MobileNetwork network = order.network;
      final List<AgentDirectoryEntry> currentAgents =
          List<AgentDirectoryEntry>.from(_agents);
      if (currentAgents.isEmpty) {
        _reservedAmounts = const <String, int>{};
        return;
      }

      final List<MapEntry<String, int>> entries = await Future.wait(
        currentAgents.map((AgentDirectoryEntry agent) async {
          try {
            final int amount = await ordersRepository.fetchActiveReservedAmount(
              agentId: agent.userId,
              network: network,
            );
            return MapEntry<String, int>(agent.userId, amount);
          } catch (_) {
            // Le repository hybride fournit deja la valeur Firebase de repli..
            // On conserve ici l'ancienne valeur plutot que d'afficher 0 et de
            // faire croire que toute la capacite est redevenue disponible.
            return MapEntry<String, int>(
              agent.userId,
              _reservedAmounts[agent.userId] ?? 0,
            );
          }
        }),
      );
      if (_isDisposed) return;
      _reservedAmounts = <String, int>{
        for (final MapEntry<String, int> entry in entries)
          entry.key: entry.value,
      };
      notifyListeners();
    } finally {
      _reservedRefreshInFlight = false;
      if (_reservedRefreshPending && !_isDisposed) {
        _reservedRefreshPending = false;
        unawaited(_refreshReservedAmounts());
      }
    }
  }

  Future<bool> assign(AgentAssignmentCandidate candidate) async {
    if (_assigningAgentId != null ||
        !candidate.isAssignable ||
        !canAssignCanonically) {
      return false;
    }

    _assigningAgentId = candidate.agent.userId;
    _errorMessage = null;
    notifyListeners();

    try {
      order = await ordersRepository.assignToAgent(
        orderId: order.id,
        agentId: candidate.agent.userId,
        assignedByUserId: adminUserId,
      );
      // Phase 4 est la source canonique avant l'acceptation Agent.
      return true;
    } on FirebaseException catch (error, stackTrace) {
      IzyTelLog.backendError(
        'AgentAssignment.assign',
        error,
        stackTrace: stackTrace,
      );
      _errorMessage = _friendlyError(error);
      return false;
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'AgentAssignment.assign',
        error,
        stackTrace: stackTrace,
      );
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _assigningAgentId = null;
      notifyListeners();
    }
  }

  String _friendlyError(Object error) {
    final String raw = error.toString();
    if (raw.startsWith('Bad state: ')) {
      return raw.substring('Bad state: '.length);
    }
    if (raw.contains('STAFF_REQUIRED')) {
      return 'Ce compte Manager n’est pas encore activé dans Supabase. '           'Ajoute son UID dans izytel_staff_access avec le rôle manager, puis reconnecte-toi.';
    }
    if (raw.contains('SocketException') ||
        raw.contains('ClientException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('PostgrestException')) {
      return 'La synchronisation des affectations est temporairement '
          'indisponible. Réessaie dans quelques secondes.';
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Firestore refuse l’affectation (permission-denied).';
        case 'failed-precondition':
          return 'L’affectation ne remplit plus les conditions requises.';
        case 'unavailable':
          return 'Firestore est temporairement indisponible. Réessaie.';
        default:
          return 'Impossible d’affecter la commande (${error.code}).';
      }
    }
    return 'Impossible d’affecter la commande pour le moment.';
  }

  AgentNetwork _agentNetwork(MobileNetwork network) {
    switch (network) {
      case MobileNetwork.orange:
        return AgentNetwork.orange;
      case MobileNetwork.mtn:
        return AgentNetwork.mtn;
      case MobileNetwork.moov:
        return AgentNetwork.moov;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _agentsSubscription?.cancel();
    _zonesSubscription?.cancel();
    _assignmentCountsSubscription?.cancel();
    super.dispose();
  }
}
