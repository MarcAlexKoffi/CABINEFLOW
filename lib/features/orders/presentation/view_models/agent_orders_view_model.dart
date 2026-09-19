import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/order_proof.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/agent_assignment_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/services/agent_order_priority_policy.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  StreamSubscription<List<QueueOrder>>? _refusedHistorySubscription;
  StreamSubscription<AgentProfile?>? _profileSubscription;
  StreamSubscription<AgentPersonalProfile?>? _personalProfileSubscription;
  AgentProfile? _agentProfile;
  AgentPersonalProfile? _personalProfile;
  String? _avatarUrl;
  List<QueueOrder> _orders = const <QueueOrder>[];
  List<QueueOrder> _refusedHistoryOrders = const <QueueOrder>[];
  AgentOrdersTab _selectedTab = AgentOrdersTab.toAccept;
  String? _busyOrderId;
  String? _errorMessage;
  bool _errorIsQueueLoad = false;
  bool _isLoading = true;

  AgentOrdersTab get selectedTab => _selectedTab;
  AgentProfile? get agentProfile => _agentProfile;
  AgentPersonalProfile? get personalProfile => _personalProfile;
  String? get avatarUrl => _avatarUrl;
  String? get busyOrderId => _busyOrderId;
  String? get errorMessage => _errorMessage;
  String get errorTitle => _errorIsQueueLoad
      ? 'Impossible de charger la file'
      : 'Action impossible';
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

  List<QueueOrder> get successfulHistoryOrders =>
      AgentOrderPriorityPolicy.sortCompleted(
        _orders.where((QueueOrder order) {
          return order.assignmentStatus == OrderAssignmentStatus.accepted &&
              _isCompleted(order.status) &&
              order.status != QueueOrderStatus.failed;
        }),
      );

  List<QueueOrder> get failedOrders => AgentOrderPriorityPolicy.sortCompleted(
    _orders.where((QueueOrder order) {
      return order.assignmentStatus == OrderAssignmentStatus.accepted &&
          order.status == QueueOrderStatus.failed;
    }),
  );

  List<QueueOrder> get refusedHistoryOrders =>
      AgentOrderPriorityPolicy.sortCompleted(_refusedHistoryOrders);

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
  int get successfulHistoryCount => successfulHistoryOrders.length;
  int get failedCount => failedOrders.length;
  int get refusedHistoryCount => refusedHistoryOrders.length;

  bool _hasOrdersForTab(AgentOrdersTab tab) {
    return switch (tab) {
      AgentOrdersTab.toAccept => toAcceptCount > 0,
      AgentOrdersTab.inProgress => inProgressCount > 0,
      AgentOrdersTab.completed => completedCount > 0,
    };
  }

  AgentOrdersTab _resolveUsefulTab(AgentOrdersTab preferred) {
    if (_hasOrdersForTab(preferred)) return preferred;
    if (toAcceptCount > 0) return AgentOrdersTab.toAccept;
    if (inProgressCount > 0) return AgentOrdersTab.inProgress;
    if (completedCount > 0) return AgentOrdersTab.completed;
    return AgentOrdersTab.toAccept;
  }

  void _syncSelectedTabToAvailableQueue() {
    _selectedTab = _resolveUsefulTab(_selectedTab);
  }

  QueueOrder? orderById(String orderId) {
    for (final QueueOrder order in _orders) {
      if (order.id == orderId) return order;
    }
    for (final QueueOrder order in _refusedHistoryOrders) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  QueueOrder? orderByReference(String reference) {
    final String normalized = reference.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    for (final QueueOrder order in _orders) {
      if (order.reference.trim().toUpperCase() == normalized) return order;
    }
    for (final QueueOrder order in _refusedHistoryOrders) {
      if (order.reference.trim().toUpperCase() == normalized) return order;
    }
    return null;
  }

  Future<void> start() async {
    _isLoading = true;
    _errorMessage = null;
    _errorIsQueueLoad = false;
    notifyListeners();

    await _subscription?.cancel();
    await _refusedHistorySubscription?.cancel();
    await _profileSubscription?.cancel();
    await _personalProfileSubscription?.cancel();

    _subscription = ordersRepository
        .watchAssignedOrders(agentId: agentId)
        .listen(
          (List<QueueOrder> orders) {
            _orders = orders
                .where((QueueOrder order) => order.assignedAgentId == agentId)
                .toList(growable: false);
            _syncSelectedTabToAvailableQueue();
            _isLoading = false;
            _errorMessage = null;
            _errorIsQueueLoad = false;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            _isLoading = false;
            IzyTelLog.backendError(
              'AgentOrders.watch-assigned',
              error,
              stackTrace: stackTrace,
            );
            // Une coupure transitoire ne doit pas transformer une file deja
            // affichee en ecran d'erreur. On conserve la derniere valeur utile.
            if (_orders.isEmpty) {
              _errorIsQueueLoad = true;
              _errorMessage = 'Impossible de charger tes commandes affectées.';
            }
            notifyListeners();
          },
        );

    if (ordersRepository is AgentAssignmentHistoryRepository) {
      final AgentAssignmentHistoryRepository historyRepository =
          ordersRepository as AgentAssignmentHistoryRepository;
      _refusedHistorySubscription = historyRepository
          .watchAgentRefusedOrders(agentId: agentId)
          .listen(
            (List<QueueOrder> orders) {
              _refusedHistoryOrders = orders;
              notifyListeners();
            },
            onError: (Object error, StackTrace stackTrace) {
              IzyTelLog.backendError(
                'Phase4.refused-history',
                error,
                stackTrace: stackTrace,
              );
            },
          );
    } else {
      _refusedHistoryOrders = const <QueueOrder>[];
    }

    final AgentRepository? repository = agentRepository;
    if (repository != null) {
      _profileSubscription = repository
          .watchAgentProfile(agentId)
          .listen(
            (AgentProfile? profile) {
              _agentProfile = profile;
              notifyListeners();
            },
            onError: (Object error, StackTrace stackTrace) {
              IzyTelLog.backendError(
                'AutoAssignment.watch-profile',
                error,
                stackTrace: stackTrace,
              );
            },
          );
      _personalProfileSubscription = repository
          .watchPersonalProfile(agentId)
          .listen(
            (AgentPersonalProfile? profile) {
              _personalProfile = profile;
              final String? path = profile?.avatarStoragePath;
              if (path == null || path.trim().isEmpty) {
                _avatarUrl = null;
                notifyListeners();
                return;
              }
              unawaited(_resolveAvatar(repository, path));
              notifyListeners();
            },
            onError: (Object error, StackTrace stackTrace) {
              IzyTelLog.backendError(
                'AgentProfile.watch-personal',
                error,
                stackTrace: stackTrace,
              );
            },
          );
    }
  }

  Future<void> _resolveAvatar(
    AgentRepository repository,
    String storagePath,
  ) async {
    final String? resolved = await repository.resolvePersonalFileUrl(
      storagePath,
    );
    if (_personalProfile?.avatarStoragePath != storagePath) return;
    _avatarUrl = resolved;
    notifyListeners();
  }

  void selectTab(AgentOrdersTab tab) {
    final AgentOrdersTab resolved = _resolveUsefulTab(tab);
    if (_selectedTab == resolved) return;
    _selectedTab = resolved;
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
    _errorIsQueueLoad = false;
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
      _errorIsQueueLoad = false;
      _errorMessage = 'Indique un motif de refus plus précis.';
      notifyListeners();
      return false;
    }

    _busyOrderId = order.id;
    _errorMessage = null;
    _errorIsQueueLoad = false;
    notifyListeners();

    try {
      final QueueOrder refused = await ordersRepository.refuseAgentAssignment(
        orderId: order.id,
        agentId: agentId,
        reason: cleanedReason,
      );
      _orders = _orders
          .where((QueueOrder item) => item.id != order.id)
          .toList(growable: false);
      _refusedHistoryOrders = <QueueOrder>[
        refused,
        ..._refusedHistoryOrders.where(
          (QueueOrder item) => item.id != refused.id,
        ),
      ];
      _syncSelectedTabToAvailableQueue();
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
    _errorIsQueueLoad = false;
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
    _errorIsQueueLoad = false;
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
      _errorIsQueueLoad = false;
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
    _errorIsQueueLoad = false;
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
    _errorIsQueueLoad = false;
    notifyListeners();

    try {
      final QueueOrder updated = await ordersRepository.markAgentSuccessful(
        orderId: order.id,
        agentId: agentId,
      );
      _replaceOrder(updated);
      _selectNextWorkTabAfterCompletion();
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
    _errorIsQueueLoad = false;
    notifyListeners();

    try {
      final QueueOrder updated = await ordersRepository.markAgentFailed(
        orderId: order.id,
        agentId: agentId,
        reason: reason,
        observation: observation,
      );
      _replaceOrder(updated);
      _selectNextWorkTabAfterCompletion();
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
    _errorIsQueueLoad = false;
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

  void _selectNextWorkTabAfterCompletion() {
    if (inProgressOrders.isNotEmpty) {
      _selectedTab = AgentOrdersTab.inProgress;
      return;
    }
    _selectedTab = AgentOrdersTab.toAccept;
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
    _syncSelectedTabToAvailableQueue();
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
      switch (error.code) {
        case 'permission-denied':
          return 'Firebase refuse encore cette action. Actualise puis réessaie.';
        case 'failed-precondition':
          return 'Cette action n’est plus compatible avec l’état actuel de la commande.';
        case 'unavailable':
          return 'Firebase est momentanément indisponible. Réessaie dans un instant.';
        case 'aborted':
          return 'L’action a été interrompue par une mise à jour concurrente. Réessaie.';
        default:
          return 'Une erreur Firebase empêche cette action pour le moment.';
      }
    }

    if (error is StorageException) {
      final String raw = error.toString().toLowerCase();
      if (raw.contains('row-level security') ||
          raw.contains('unauthorized') ||
          raw.contains('forbidden') ||
          raw.contains('403')) {
        return 'Supabase refuse l’enregistrement de la preuve pour cette commande. Actualise la commande puis réessaie.';
      }
      if (raw.contains('payload too large') || raw.contains('413')) {
        return 'La photo est encore trop lourde. Choisis une image plus légère.';
      }
      if (raw.contains('network') ||
          raw.contains('timeout') ||
          raw.contains('connection')) {
        return 'La preuve n’a pas pu être envoyée. Vérifie la connexion puis réessaie.';
      }
      return 'Impossible d’enregistrer la preuve dans Supabase. Réessaie.';
    }

    if (error is PostgrestException) {
      final String raw = '${error.code ?? ''} ${error.message}'.toLowerCase();
      if (raw.contains('pgrst303') || raw.contains('jwt issued at future')) {
        return 'L’horloge du téléphone et la session Supabase ne sont pas synchronisées. Active la date et l’heure automatiques puis actualise.';
      }
      if (raw.contains('42501') || raw.contains('permission')) {
        return 'Supabase refuse cette action pour l’état actuel de la commande.';
      }
      if (raw.contains('order_not_accepted') ||
          raw.contains('order_not_handed_off')) {
        return 'La commande doit être acceptée avant l’ajout de la preuve.';
      }
      if (raw.contains('order_not_in_progress')) {
        return 'Démarre le traitement de la commande avant d’ajouter la preuve.';
      }
      if (raw.contains('order_reference_mismatch') ||
          raw.contains('invalid_proof_path')) {
        return 'La preuve ne correspond pas à cette commande. Actualise puis reprends la photo.';
      }
      if (raw.contains('proof_required')) {
        return 'Ajoute une preuve avant de valider la réussite.';
      }
      if (raw.contains('insufficient_capacity')) {
        return 'La capacité du réseau est devenue insuffisante avant la finalisation.';
      }
      return 'Supabase n’a pas pu confirmer cette action. Actualise puis réessaie.';
    }

    final String raw = error.toString();
    final String normalized = raw.toLowerCase();
    if (normalized.contains('socketexception') ||
        normalized.contains('timeoutexception') ||
        normalized.contains('clientexception') ||
        normalized.contains('connection reset') ||
        normalized.contains('connection closed')) {
      return 'Connexion interrompue pendant l’action. Vérifie le réseau puis réessaie.';
    }
    if (normalized.contains('jwt') &&
        (normalized.contains('expired') || normalized.contains('invalid'))) {
      return 'La session a expiré. Actualise la page puis réessaie.';
    }
    if (raw.startsWith('Bad state: ')) {
      return raw.substring('Bad state: '.length);
    }
    if (raw.startsWith('StateError: ')) {
      return raw.substring('StateError: '.length);
    }
    return 'Une erreur inattendue est survenue. Réessaie.';
  }

  void _logActionError(String action, Object error, StackTrace stackTrace) {
    IzyTelLog.backendError(
      'AgentOrders.$action',
      error,
      stackTrace: stackTrace,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _refusedHistorySubscription?.cancel();
    _profileSubscription?.cancel();
    _personalProfileSubscription?.cancel();
    super.dispose();
  }
}
