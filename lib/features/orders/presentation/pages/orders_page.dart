import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/order_history_filters.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/orders_view_model.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/orders_widgets.dart';
import 'package:cabine_flow/features/support/data/repositories/fake_support_request_repository.dart';
import 'package:cabine_flow/features/support/data/repositories/firestore_support_request_repository.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cabine_flow/features/orders/presentation/pages/agent_assignment_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/order_detail_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/order_history_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/order_processing_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/customer_confirmation_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    required this.agentRepository,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final AgentRepository agentRepository;

  @override
  State<OrdersPage> createState() {
    return _OrdersPageState();
  }
}

class _OrdersPageState extends State<OrdersPage> {
  late final OrdersViewModel _viewModel;
  int _activeTabIndex = 0;
  bool _showHistory = false;
  bool _openHistoryFiltersOnStart = false;
  int _historyVersion = 0;
  String _historyInitialSearchQuery = '';
  OrderHistoryFilters _historyInitialFilters = const OrderHistoryFilters();
  QueueOrder? _detailOrder;
  late final SupportRequestRepository _supportRequestRepository;

  Future<void> _markTransactionSuccessful() async {
    final bool isSuccessful = await _viewModel.markActiveOrderSuccessful();

    if (!mounted) {
      return;
    }

    if (!isSuccessful) {
      final String message =
          _viewModel.errorMessage ?? 'Impossible de terminer la commande.';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));

      return;
    }

    final QueueOrder? confirmationOrder = _viewModel.activeOrder;

    if (confirmationOrder == null) {
      return;
    }

    final bool? messageWasSent = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (BuildContext routeContext) {
          return CustomerConfirmationPage(
            order: confirmationOrder,
            onComplete: (bool messageSent) {
              return _viewModel.completeCustomerConfirmation(
                messageSent: messageSent,
              );
            },
          );
        },
      ),
    );

    if (!mounted || messageWasSent == null) {
      return;
    }

    final String message = messageWasSent
        ? 'La commande ${confirmationOrder.reference} est terminée '
              'et le message client est enregistré comme envoyé.'
        : 'La commande ${confirmationOrder.reference} est terminée '
              'sans envoi du message client.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _markTransactionFailed(
    OrderFailureReason reason,
    String? observation,
  ) async {
    final QueueOrder? order = _viewModel.activeOrder;

    final bool isSuccessful = await _viewModel.markActiveOrderFailed(
      reason: reason,
      observation: observation,
    );

    if (!mounted) {
      return;
    }

    final String message = isSuccessful
        ? 'L’échec de la commande ${order?.reference ?? ''} est enregistré.'
        : _viewModel.errorMessage ?? 'Impossible d’enregistrer l’échec.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _putTransactionOnHold() async {
    final QueueOrder? order = _viewModel.activeOrder;

    final bool isSuccessful = await _viewModel.putActiveOrderOnHold();

    if (!mounted) {
      return;
    }

    final String message = isSuccessful
        ? 'La commande ${order?.reference ?? ''} retourne dans la file.'
        : _viewModel.errorMessage ??
              'Impossible de mettre la commande en attente.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();

    _viewModel = OrdersViewModel(
      ordersRepository: widget.ordersRepository,
      orderHistoryRepository: _historyRepository,
    );
    _supportRequestRepository = Firebase.apps.isNotEmpty
        ? FirestoreSupportRequestRepository()
        : FakeSupportRequestRepository();

    _viewModel.startRealtime();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  OrderHistoryRepository? get _historyRepository {
    final OrdersRepository repository = widget.ordersRepository;
    if (repository is OrderHistoryRepository) {
      return repository as OrderHistoryRepository;
    }
    return null;
  }

  void _showHistoryUnavailable() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'L’historique n’est pas disponible avec ce dépôt de données.',
          ),
        ),
      );
  }

  void _openHistory({
    String initialSearchQuery = '',
    OrderHistoryFilters initialFilters = const OrderHistoryFilters(),
    bool openFiltersOnStart = false,
  }) {
    if (_historyRepository == null) {
      _showHistoryUnavailable();
      return;
    }

    setState(() {
      _showHistory = true;
      _detailOrder = null;
      _historyInitialSearchQuery = initialSearchQuery;
      _historyInitialFilters = initialFilters;
      _openHistoryFiltersOnStart = openFiltersOnStart;
      _historyVersion++;
    });
  }

  void _closeHistory() {
    setState(() {
      _showHistory = false;
      _detailOrder = null;
      _activeTabIndex = 0;
    });

    _viewModel.loadQueue();
  }

  void _openOrderDetail(
    QueueOrder order,
    String searchQuery,
    OrderHistoryFilters filters,
  ) {
    if (_historyRepository == null) {
      _showHistoryUnavailable();
      return;
    }

    setState(() {
      _historyInitialSearchQuery = searchQuery;
      _historyInitialFilters = filters;
      _openHistoryFiltersOnStart = false;
      _detailOrder = order;
      _showHistory = false;
    });
  }

  void _closeOrderDetail() {
    setState(() {
      _detailOrder = null;
      _showHistory = true;
      _historyVersion++;
    });
  }

  void _openCustomerHistory(String whatsappPhone) {
    _openHistory(initialSearchQuery: whatsappPhone);
  }

  void _handleOrdersTabChanged(int index) {
    if (index == 0) {
      setState(() {
        _activeTabIndex = 0;
      });
      return;
    }

    final OrderHistoryStateFilter state = index == 1
        ? OrderHistoryStateFilter.active
        : OrderHistoryStateFilter.completed;

    setState(() {
      _activeTabIndex = index;
    });

    _openHistory(
      initialFilters: OrderHistoryFilters(
        states: <OrderHistoryStateFilter>{state},
      ),
    );
  }

  String _filterLabel(QueueFilter filter) {
    switch (filter) {
      case QueueFilter.all:
        return 'Tous';

      case QueueFilter.orange:
        return 'Orange';

      case QueueFilter.mtn:
        return 'MTN';

      case QueueFilter.moov:
        return 'Moov';
    }
  }

  Future<void> _openAgentAssignment(QueueOrder order) async {
    final QueueOrder? updatedOrder = await Navigator.of(context)
        .push<QueueOrder>(
          MaterialPageRoute<QueueOrder>(
            fullscreenDialog: true,
            builder: (BuildContext routeContext) {
              return AgentAssignmentPage(
                user: widget.user,
                order: order,
                agentRepository: widget.agentRepository,
                ordersRepository: widget.ordersRepository,
              );
            },
          ),
        );

    if (!mounted || updatedOrder == null) return;

    await _viewModel.loadQueue();
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Commande ${updatedOrder.reference} affectée à ${updatedOrder.assignedAgentName ?? 'l’agent'}.',
          ),
        ),
      );
  }

  Future<void> _confirmTakeCharge(QueueOrder order) async {
    final bool? isConfirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Prendre en charge'),
          content: Text(
            'Confirmer la prise en charge de la commande '
            '${order.reference} pour le numéro '
            '${order.beneficiaryPhone} ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );

    if (isConfirmed != true) {
      return;
    }

    final bool isSuccessful = await _viewModel.takeCharge(
      orderId: order.id,
      operatorId: widget.user.id,
    );

    if (!mounted) {
      return;
    }

    if (isSuccessful) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'La commande ${order.reference} est maintenant en cours.',
            ),
          ),
        );

      return;
    }

    final String message =
        _viewModel.errorMessage ??
        'Impossible de prendre en charge la commande.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final QueueOrder? detailOrder = _detailOrder;
    final OrderHistoryRepository? historyRepository = _historyRepository;

    if (detailOrder != null && historyRepository != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (!didPop) _closeOrderDetail();
        },
        child: OrderDetailPage(
          user: widget.user,
          initialOrder: detailOrder,
          ordersRepository: historyRepository,
          onBack: _closeOrderDetail,
          onOpenCustomerHistory: _openCustomerHistory,
          supportRequestRepository: _supportRequestRepository,
        ),
      );
    }

    if (_showHistory && historyRepository != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (!didPop) _closeHistory();
        },
        child: OrderHistoryPage(
          key: ValueKey<int>(_historyVersion),
          user: widget.user,
          ordersRepository: historyRepository,
          onBack: _closeHistory,
          onOpenOrder: _openOrderDetail,
          initialSearchQuery: _historyInitialSearchQuery,
          initialFilters: _historyInitialFilters,
          openFiltersOnStart: _openHistoryFiltersOnStart,
        ),
      );
    }

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, Widget? child) {
        final List<QueueOrder> orders = _viewModel.filteredOrders;
        final QueueOrder? activeOrder = _viewModel.activeOrder;

        if (activeOrder != null &&
            activeOrder.status == QueueOrderStatus.inProgress) {
          return OrderProcessingPage(
            user: widget.user,
            order: activeOrder,
            isSubmitting: _viewModel.isProcessingAction,
            onTransactionSucceeded: _markTransactionSuccessful,
            onTransactionFailed: _markTransactionFailed,
            onPutOnHold: _putTransactionOnHold,
            onNotificationsPressed: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(
                      'L’écran des notifications sera ajouté ultérieurement.',
                    ),
                  ),
                );
            },
          );
        }

        if (activeOrder != null &&
            activeOrder.status ==
                QueueOrderStatus.awaitingCustomerConfirmation) {
          return const Center(child: CircularProgressIndicator());
        }
        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                color: IzyTelColors.background,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: OrdersTopBar(
                  user: widget.user,
                  subtitle:
                      '${_viewModel.allReadyOrders.length} à traiter aujourd’hui',
                  onSearchPressed: () {
                    _openHistory();
                  },
                  onFiltersPressed: () {
                    _openHistory(openFiltersOnStart: true);
                  },
                  onNotificationsPressed: () {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text(
                            'L’écran des notifications sera ajouté ultérieurement.',
                          ),
                        ),
                      );
                  },
                ),
              ),
              const Divider(height: 1, color: IzyTelColors.outline),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _viewModel.loadQueue,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: OrdersTabs(
                          todoCount: _viewModel.allReadyOrders.length,
                          inProgressCount: _viewModel.inProgressCount,
                          completedCount: _viewModel.completedCount,
                          activeTabIndex: _activeTabIndex,
                          onTabChanged: _handleOrdersTabChanged,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...QueueFilter.values.map((QueueFilter filter) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: QueueFilterButton(
                                    label: _filterLabel(filter),
                                    count: _viewModel.countForFilter(filter),
                                    isSelected:
                                        _viewModel.selectedFilter == filter,
                                    onPressed: () {
                                      _viewModel.selectFilter(filter);
                                    },
                                  ),
                                );
                              }),
                              OutlinedButton.icon(
                                onPressed: () {
                                  _openHistory(openFiltersOnStart: true);
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 32),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: const StadiumBorder(),
                                  side: const BorderSide(
                                    color: IzyTelColors.outline,
                                  ),
                                ),
                                icon: const Icon(
                                  Symbols.tune_rounded,
                                  size: IzyTelIconSize.info,
                                ),
                                label: const Text(
                                  'Filtres',
                                  style: TextStyle(
                                    fontSize: IzyTelTypeScale.label,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_viewModel.errorMessage != null &&
                          _viewModel.hasOrders) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: IzyTelColors.errorSoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: IzyTelColors.error.withAlpha(90),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Symbols.error_rounded,
                                color: IzyTelColors.error,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _viewModel.errorMessage!,
                                  style: const TextStyle(
                                    color: IzyTelColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_viewModel.isLoading && !_viewModel.hasOrders)
                        const SizedBox(
                          height: 300,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (!_viewModel.hasOrders)
                        const QueueEmptyState()
                      else if (orders.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: IzyTelColors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: IzyTelColors.outline),
                          ),
                          child: const Text(
                            'Aucune commande ne correspond à ce filtre.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ...orders.map((QueueOrder order) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: QueueOrderCard(
                              order: order,
                              position: _viewModel.positionOf(order.id),
                              waitingMinutes: _viewModel.waitingMinutes(order),
                              isUrgent: _viewModel.isUrgent(order),
                              isProcessing: _viewModel.isTakingCharge(order.id),
                              actionLabel: order.isAssignedToAgent
                                  ? 'En attente de l’agent'
                                  : widget.user.role == UserRole.administrator
                                  ? order.manualAssignmentRequired
                                        ? 'Affecter manuellement'
                                        : 'Affecter'
                                  : 'Prendre en charge',
                              assignmentLabel: order.assignedAgentName,
                              isActionEnabled: true,
                              onTakeCharge: () {
                                if (order.isAssignedToAgent &&
                                    _historyRepository != null) {
                                  _openOrderDetail(
                                    order,
                                    '',
                                    const OrderHistoryFilters(),
                                  );
                                  return;
                                }
                                if (widget.user.role ==
                                    UserRole.administrator) {
                                  _openAgentAssignment(order);
                                } else {
                                  _confirmTakeCharge(order);
                                }
                              },
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
