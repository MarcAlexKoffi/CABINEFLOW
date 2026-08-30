import 'dart:async';

import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/automatic_assignment.dart';
import 'package:cabine_flow/features/orders/domain/models/order_proof.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/services/agent_order_priority_policy.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

enum AgentOrdersTab { toAccept, inProgress, completed }

class AgentOrdersViewModel extends ChangeNotifier {
  AgentOrdersViewModel({
    required this.agentId,
    required this.ordersRepository,
    this.agentRepository,
  });

  final String agentId;
  final OrdersRepository ordersRepository;
  final AgentRepository? agentRepository;

  StreamSubscription<List<QueueOrder>>? _subscription;
  StreamSubscription<AgentProfile?>? _profileSubscription;
  StreamSubscription<List<AutomaticAssignmentQueueItem>>?
  _autoQueueSubscription;
  Timer? _autoClaimTimer;
  AgentProfile? _agentProfile;
  List<AutomaticAssignmentQueueItem> _autoQueue =
      const <AutomaticAssignmentQueueItem>[];
  bool _autoClaimInFlight = false;
  List<QueueOrder> _orders = const <QueueOrder>[];
  AgentOrdersTab _selectedTab = AgentOrdersTab.toAccept;
  String? _busyOrderId;
  String? _errorMessage;
  bool _isLoading = true;

  AgentOrdersTab get selectedTab => _selectedTab;
  AgentProfile? get agentProfile => _agentProfile;
  String? get busyOrderId => _busyOrderId;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  List<QueueOrder> get toAcceptOrders =>
      AgentOrderPriorityPolicy.sortActiveQueue(
        _orders.where((QueueOrder order) {
          return order.assignmentStatus == OrderAssignmentStatus.assigned;
        }),
      );

  List<QueueOrder> get inProgressOrders =>
      AgentOrderPriorityPolicy.sortActiveQueue(
        _orders.where((QueueOrder order) {
          return order.assignmentStatus == OrderAssignmentStatus.accepted &&
              !_isCompleted(order.status);
        }),
      );

  List<QueueOrder> get completedOrders =>
      AgentOrderPriorityPolicy.sortCompleted(
        _orders.where((QueueOrder order) {
          return order.assignmentStatus == OrderAssignmentStatus.accepted &&
              _isCompleted(order.status);
        }),
      );

  List<QueueOrder> get visibleOrders {
    switch (_selectedTab) {
      case AgentOrdersTab.toAccept:
        return toAcceptOrders;
      case AgentOrdersTab.inProgress:
        return inProgressOrders;
      case AgentOrdersTab.completed:
        return completedOrders;
    }
  }

  int get toAcceptCount => toAcceptOrders.length;
  int get inProgressCount => inProgressOrders.length;
  int get completedCount => completedOrders.length;

  QueueOrder? orderById(String orderId) {
    for (final QueueOrder order in _orders) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  Future<void> start() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await _subscription?.cancel();
    await _profileSubscription?.cancel();
    await _autoQueueSubscription?.cancel();
    _autoClaimTimer?.cancel();

    _subscription = ordersRepository
        .watchAssignedOrders(agentId: agentId)
        .listen(
          (List<QueueOrder> orders) {
            _orders = orders
                .where((QueueOrder order) => order.assignedAgentId == agentId)
                .toList(growable: false);
            _isLoading = false;
            _errorMessage = null;
            _scheduleAutomaticClaim();
            notifyListeners();
          },
          onError: (_) {
            _isLoading = false;
            _errorMessage = 'Impossible de charger tes commandes affectées.';
            notifyListeners();
          },
        );

    final AgentRepository? repository = agentRepository;
    if (repository != null) {
      _profileSubscription = repository
          .watchAgentProfile(agentId)
          .listen(
            (AgentProfile? profile) {
              _agentProfile = profile;
              _scheduleAutomaticClaim();
            },
            onError: (Object error) {
              debugPrint('[AutoAssignment][watch-profile] $error');
            },
          );
      _autoQueueSubscription = ordersRepository
          .watchAutomaticAssignmentQueue()
          .listen(
            (List<AutomaticAssignmentQueueItem> items) {
              _autoQueue = items;
              _scheduleAutomaticClaim();
            },
            onError: (Object error) {
              debugPrint('[AutoAssignment][watch-queue] $error');
            },
          );
    }
  }

  void selectTab(AgentOrdersTab tab) {
    if (_selectedTab == tab) return;
    _selectedTab = tab;
    notifyListeners();
  }

  Future<bool> accept(QueueOrder order) async {
    if (_busyOrderId != null ||
        order.assignedAgentId != agentId ||
        order.assignmentStatus != OrderAssignmentStatus.assigned) {
      return false;
    }

    _busyOrderId = order.id;
    _errorMessage = null;
    notifyListeners();

    try {
      final QueueOrder updated = await ordersRepository.acceptAgentAssignment(
        orderId: order.id,
        agentId: agentId,
      );
      _replaceOrder(updated);
      _selectedTab = AgentOrdersTab.inProgress;
      return true;
    } catch (error, stackTrace) {
      _logActionError('accept', error, stackTrace);
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _busyOrderId = null;
      notifyListeners();
    }
  }

  Future<bool> refuse(QueueOrder order, String reason) async {
    if (_busyOrderId != null ||
        order.assignedAgentId != agentId ||
        order.assignmentStatus != OrderAssignmentStatus.assigned) {
      return false;
    }

    final String cleanedReason = reason.trim();
    if (cleanedReason.length < 3) {
      _errorMessage = 'Indique un motif de refus plus précis.';
      notifyListeners();
      return false;
    }

    _busyOrderId = order.id;
    _errorMessage = null;
    notifyListeners();

    try {
      await ordersRepository.refuseAgentAssignment(
        orderId: order.id,
        agentId: agentId,
        reason: cleanedReason,
      );
      _orders = _orders
          .where((QueueOrder item) => item.id != order.id)
          .toList(growable: false);
      return true;
    } catch (error, stackTrace) {
      _logActionError('refuse', error, stackTrace);
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _busyOrderId = null;
      notifyListeners();
    }
  }

  Future<bool> startProcessing(QueueOrder order) async {
    if (!_canActOnAcceptedOrder(order)) return false;
    _busyOrderId = order.id;
    _errorMessage = null;
    notifyListeners();

    try {
      final QueueOrder updated = await ordersRepository.startAgentProcessing(
        orderId: order.id,
        agentId: agentId,
      );
      _replaceOrder(updated);
      _selectedTab = AgentOrdersTab.inProgress;
      return true;
    } catch (error, stackTrace) {
      _logActionError('start', error, stackTrace);
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _busyOrderId = null;
      notifyListeners();
    }
  }

  Future<bool> resumeProcessing(QueueOrder order) async {
    if (!_canActOnAcceptedOrder(order)) return false;
    _busyOrderId = order.id;
    _errorMessage = null;
    notifyListeners();

    try {
      final QueueOrder updated = await ordersRepository.resumeAgentProcessing(
        orderId: order.id,
        agentId: agentId,
      );
      _replaceOrder(updated);
      return true;
    } catch (error, stackTrace) {
      _logActionError('resume', error, stackTrace);
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _busyOrderId = null;
      notifyListeners();
    }
  }

  Future<OrderProof?> loadProof(String orderId) async {
    try {
      return await ordersRepository.fetchOrderProof(orderId: orderId);
    } catch (error, stackTrace) {
      _logActionError('load-proof', error, stackTrace);
      _errorMessage = _friendlyError(error);
      notifyListeners();
      return null;
    }
  }

  Future<OrderProof?> saveProof({
    required QueueOrder order,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    if (!_canActOnAcceptedOrder(order)) return null;
    _busyOrderId = order.id;
    _errorMessage = null;
    notifyListeners();

    try {
      return await ordersRepository.saveOrderProof(
        orderId: order.id,
        orderReference: order.reference,
        agentId: agentId,
        fileName: fileName,
        mimeType: mimeType,
        bytes: bytes,
      );
    } catch (error, stackTrace) {
      _logActionError('save-proof', error, stackTrace);
      _errorMessage = _friendlyError(error);
      return null;
    } finally {
      _busyOrderId = null;
      notifyListeners();
    }
  }

  Future<bool> markSuccessful(QueueOrder order) async {
    if (!_canActOnAcceptedOrder(order)) return false;
    _busyOrderId = order.id;
    _errorMessage = null;
    notifyListeners();

    try {
      final QueueOrder updated = await ordersRepository.markAgentSuccessful(
        orderId: order.id,
        agentId: agentId,
      );
      _replaceOrder(updated);
      _selectedTab = AgentOrdersTab.completed;
      return true;
    } catch (error, stackTrace) {
      _logActionError('success', error, stackTrace);
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _busyOrderId = null;
      notifyListeners();
    }
  }

  Future<bool> markFailed(
    QueueOrder order,
    OrderFailureReason reason,
    String? observation,
  ) async {
    if (!_canActOnAcceptedOrder(order)) return false;
    _busyOrderId = order.id;
    _errorMessage = null;
    notifyListeners();

    try {
      final QueueOrder updated = await ordersRepository.markAgentFailed(
        orderId: order.id,
        agentId: agentId,
        reason: reason,
        observation: observation,
      );
      _replaceOrder(updated);
      _selectedTab = AgentOrdersTab.completed;
      return true;
    } catch (error, stackTrace) {
      _logActionError('failure', error, stackTrace);
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _busyOrderId = null;
      notifyListeners();
    }
  }

  Future<bool> putOnHold(QueueOrder order, String reason) async {
    if (!_canActOnAcceptedOrder(order)) return false;
    _busyOrderId = order.id;
    _errorMessage = null;
    notifyListeners();

    try {
      final QueueOrder updated = await ordersRepository.putAgentOnHold(
        orderId: order.id,
        agentId: agentId,
        reason: reason,
      );
      _replaceOrder(updated);
      _selectedTab = AgentOrdersTab.inProgress;
      return true;
    } catch (error, stackTrace) {
      _logActionError('hold', error, stackTrace);
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _busyOrderId = null;
      notifyListeners();
    }
  }

  void _scheduleAutomaticClaim() {
    _autoClaimTimer?.cancel();
    if (_autoClaimInFlight) return;
    final AutomaticAssignmentQueueItem? item = _nextAutomaticQueueItem();
    if (item == null) return;

    final int activeCount = _orders.where(_isActiveAssignedOrder).length;
    final int todayCount = _todayAssignmentCount();
    final int jitter = _stableJitter(item.orderId, agentId);
    final int delayMs = (activeCount * 250) + todayCount + jitter;
    _autoClaimTimer = Timer(
      Duration(milliseconds: delayMs.clamp(30, 1600).toInt()),
      () => unawaited(_attemptAutomaticClaim()),
    );
  }

  Future<void> _attemptAutomaticClaim() async {
    if (_autoClaimInFlight) return;
    final AutomaticAssignmentQueueItem? item = _nextAutomaticQueueItem();
    if (item == null) return;

    _autoClaimInFlight = true;
    try {
      await ordersRepository.claimAutomaticQueueItem(
        item: item,
        agentId: agentId,
      );
    } catch (error, stackTrace) {
      debugPrint('[AutoAssignment][claim] $error');
      debugPrintStack(
        label: '[AutoAssignment][claim] stack',
        stackTrace: stackTrace,
      );
    } finally {
      _autoClaimInFlight = false;
    }
  }

  AutomaticAssignmentQueueItem? _nextAutomaticQueueItem() {
    final AgentProfile? profile = _agentProfile;
    if (profile == null ||
        profile.availability != AgentAvailability.available ||
        _autoQueue.isEmpty) {
      return null;
    }

    final int todayCount = _todayAssignmentCount();
    final int todayAmount = _todayAssignedAmount();

    // 0 = aucune limite configurée. Cela permet aux anciens profils agents
    // de participer à l'affectation automatique sans migration préalable.
    if (profile.maxTransactionsPerDay > 0 &&
        todayCount >= profile.maxTransactionsPerDay) {
      return null;
    }

    for (final AutomaticAssignmentQueueItem item in _autoQueue) {
      if (item.refusedAgentIds.contains(agentId) ||
          item.lastRefusedAgentId == agentId) {
        continue;
      }
      final AgentNetwork network = _agentNetwork(item.network);
      if (!profile.authorizedNetworks.contains(network) ||
          !profile.activeNetworks.contains(network)) {
        continue;
      }
      final int availableCapacity =
          profile.capacityFor(network) - _activeReservedAmount(network);
      if (availableCapacity < item.amount) continue;
      if (profile.dailyTransactionLimit > 0 &&
          todayAmount + item.amount > profile.dailyTransactionLimit) {
        continue;
      }
      return item;
    }
    return null;
  }

  int _activeReservedAmount(AgentNetwork network) {
    int amount = 0;
    for (final QueueOrder order in _orders) {
      if (!_isActiveAssignedOrder(order)) continue;
      if (_agentNetwork(order.network) == network) {
        amount += order.amount;
      }
    }
    return amount;
  }

  int _todayAssignmentCount() {
    final DateTime now = DateTime.now().toUtc();
    return _orders.where((QueueOrder order) {
      final DateTime? assignedAt = order.assignedAt;
      return assignedAt != null && _sameUtcDay(assignedAt.toUtc(), now);
    }).length;
  }

  int _todayAssignedAmount() {
    final DateTime now = DateTime.now().toUtc();
    int amount = 0;
    for (final QueueOrder order in _orders) {
      final DateTime? assignedAt = order.assignedAt;
      if (assignedAt != null && _sameUtcDay(assignedAt.toUtc(), now)) {
        amount += order.amount;
      }
    }
    return amount;
  }

  bool _sameUtcDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  bool _isActiveAssignedOrder(QueueOrder order) {
    if (order.assignmentStatus != OrderAssignmentStatus.assigned &&
        order.assignmentStatus != OrderAssignmentStatus.accepted) {
      return false;
    }
    return order.status != QueueOrderStatus.completed &&
        order.status != QueueOrderStatus.failed &&
        order.status != QueueOrderStatus.cancelled &&
        order.status != QueueOrderStatus.refunded;
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

  int _stableJitter(String orderId, String currentAgentId) {
    final String seed = '$orderId:$currentAgentId';
    int hash = 17;
    for (final int code in seed.codeUnits) {
      hash = ((hash * 31) + code) & 0x7fffffff;
    }
    return 30 + (hash % 100);
  }

  bool _canActOnAcceptedOrder(QueueOrder order) {
    if (_busyOrderId != null ||
        order.assignedAgentId != agentId ||
        order.assignmentStatus != OrderAssignmentStatus.accepted) {
      return false;
    }
    return true;
  }

  void _replaceOrder(QueueOrder updated) {
    _orders = _orders
        .map((QueueOrder order) => order.id == updated.id ? updated : order)
        .toList(growable: false);
  }

  bool _isCompleted(QueueOrderStatus status) {
    return status == QueueOrderStatus.completed ||
        status == QueueOrderStatus.awaitingCustomerConfirmation ||
        status == QueueOrderStatus.failed ||
        status == QueueOrderStatus.cancelled ||
        status == QueueOrderStatus.refunded;
  }

  String _friendlyError(Object error) {
    if (error is FirebaseException) {
      final String message = (error.message ?? '').trim();
      switch (error.code) {
        case 'permission-denied':
          return 'Firestore refuse cette action (permission-denied).';
        case 'failed-precondition':
          return message.isEmpty
              ? 'Précondition Firestore non satisfaite (failed-precondition).'
              : 'Firestore failed-precondition : $message';
        case 'unavailable':
          return 'Firestore est momentanément indisponible (unavailable).';
        case 'aborted':
          return 'La transaction Firestore a été interrompue (aborted). Réessaie.';
        default:
          return message.isEmpty
              ? 'Erreur Firestore (${error.code}).'
              : 'Erreur Firestore (${error.code}) : $message';
      }
    }

    final String raw = error.toString();
    if (raw.startsWith('Bad state: ')) {
      return raw.substring('Bad state: '.length);
    }
    return 'Erreur inattendue : $raw';
  }

  void _logActionError(String action, Object error, StackTrace stackTrace) {
    debugPrint('[AgentOrders][$action] ${error.runtimeType}: $error');
    if (error is FirebaseException) {
      debugPrint(
        '[AgentOrders][$action] plugin=${error.plugin} '
        'code=${error.code} message=${error.message}',
      );
    }
    debugPrintStack(
      label: '[AgentOrders][$action] stack',
      stackTrace: stackTrace,
    );
  }

  @override
  void dispose() {
    _autoClaimTimer?.cancel();
    _subscription?.cancel();
    _profileSubscription?.cancel();
    _autoQueueSubscription?.cancel();
    super.dispose();
  }
}
