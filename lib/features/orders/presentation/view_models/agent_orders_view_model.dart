import 'dart:async';

import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

enum AgentOrdersTab { toAccept, inProgress, completed }

class AgentOrdersViewModel extends ChangeNotifier {
  AgentOrdersViewModel({required this.agentId, required this.ordersRepository});

  final String agentId;
  final OrdersRepository ordersRepository;

  StreamSubscription<List<QueueOrder>>? _subscription;
  List<QueueOrder> _orders = const <QueueOrder>[];
  AgentOrdersTab _selectedTab = AgentOrdersTab.toAccept;
  String? _busyOrderId;
  String? _errorMessage;
  bool _isLoading = true;

  AgentOrdersTab get selectedTab => _selectedTab;
  String? get busyOrderId => _busyOrderId;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  List<QueueOrder> get toAcceptOrders => _sorted(
    _orders.where((QueueOrder order) {
      return order.assignmentStatus == OrderAssignmentStatus.assigned;
    }),
  );

  List<QueueOrder> get inProgressOrders => _sorted(
    _orders.where((QueueOrder order) {
      return order.assignmentStatus == OrderAssignmentStatus.accepted &&
          !_isCompleted(order.status);
    }),
  );

  List<QueueOrder> get completedOrders => _sorted(
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

  Future<void> start() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await _subscription?.cancel();
    _subscription = ordersRepository
        .watchAssignedOrders(agentId: agentId)
        .listen(
          (List<QueueOrder> orders) {
            _orders = orders
                .where((QueueOrder order) => order.assignedAgentId == agentId)
                .toList(growable: false);
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (_) {
            _isLoading = false;
            _errorMessage = 'Impossible de charger tes commandes affectées.';
            notifyListeners();
          },
        );
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

  void _replaceOrder(QueueOrder updated) {
    _orders = _orders
        .map((QueueOrder order) => order.id == updated.id ? updated : order)
        .toList(growable: false);
  }

  List<QueueOrder> _sorted(Iterable<QueueOrder> source) {
    final List<QueueOrder> result = source.toList(growable: false);
    result.sort((QueueOrder first, QueueOrder second) {
      final DateTime firstDate = first.assignedAt ?? first.createdAt;
      final DateTime secondDate = second.assignedAt ?? second.createdAt;
      return secondDate.compareTo(firstDate);
    });
    return List<QueueOrder>.unmodifiable(result);
  }

  bool _isCompleted(QueueOrderStatus status) {
    return status == QueueOrderStatus.completed ||
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
    _subscription?.cancel();
    super.dispose();
  }
}
