import 'dart:async';

import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
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
    required this.agentRepository,
    required this.ordersRepository,
  });

  QueueOrder order;
  final String adminUserId;
  final AgentRepository agentRepository;
  final OrdersRepository ordersRepository;

  StreamSubscription<List<AgentDirectoryEntry>>? _agentsSubscription;
  StreamSubscription<List<AgentZone>>? _zonesSubscription;

  List<AgentDirectoryEntry> _agents = const <AgentDirectoryEntry>[];
  List<AgentZone> _zones = const <AgentZone>[];
  Map<String, int> _activeAssignmentCounts = const <String, int>{};
  String? _assigningAgentId;
  String? _errorMessage;
  bool _isLoading = true;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get assigningAgentId => _assigningAgentId;

  List<AgentAssignmentCandidate> get candidates {
    final AgentNetwork requiredNetwork = _agentNetwork(order.network);
    final List<AgentAssignmentCandidate> result = <AgentAssignmentCandidate>[];

    for (final AgentDirectoryEntry agent in _agents) {
      final AgentProfile? profile = agent.profile;
      if (profile == null ||
          !profile.authorizedNetworks.contains(requiredNetwork)) {
        continue;
      }

      final int capacity = profile.capacityFor(requiredNetwork);
      final bool isCurrent =
          order.assignedAgentId == agent.userId &&
          order.assignmentStatus == OrderAssignmentStatus.assigned;
      String? reason;

      if (!agent.isActive) {
        reason = 'Agent suspendu';
      } else if (profile.availability != AgentAvailability.available) {
        reason = 'Indisponible';
      } else if (!profile.activeNetworks.contains(requiredNetwork)) {
        reason = 'Réseau désactivé';
      } else if (capacity < order.amount) {
        reason = 'Capacité insuffisante';
      } else if (isCurrent) {
        reason = 'Déjà affecté';
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

  Future<void> start() async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    await _agentsSubscription?.cancel();
    await _zonesSubscription?.cancel();

    _agentsSubscription = agentRepository.watchAgents().listen(
      (List<AgentDirectoryEntry> agents) {
        _agents = agents;
        _isLoading = false;
        notifyListeners();
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

    try {
      _activeAssignmentCounts = await ordersRepository
          .fetchActiveAssignmentCounts();
    } catch (_) {
      _activeAssignmentCounts = const <String, int>{};
    }
    notifyListeners();
  }

  Future<bool> assign(AgentAssignmentCandidate candidate) async {
    if (_assigningAgentId != null || !candidate.isAssignable) return false;

    _assigningAgentId = candidate.agent.userId;
    _errorMessage = null;
    notifyListeners();

    try {
      order = await ordersRepository.assignToAgent(
        orderId: order.id,
        agentId: candidate.agent.userId,
        assignedByUserId: adminUserId,
      );
      _activeAssignmentCounts = <String, int>{
        ..._activeAssignmentCounts,
        candidate.agent.userId:
            (_activeAssignmentCounts[candidate.agent.userId] ?? 0) + 1,
      };
      return true;
    } catch (error) {
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
    _agentsSubscription?.cancel();
    _zonesSubscription?.cancel();
    super.dispose();
  }
}
