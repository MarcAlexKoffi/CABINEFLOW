import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/orders_view_model.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/orders_widgets.dart';
import 'package:flutter/material.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({
    super.key,
    required this.user,
    required this.ordersRepository,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;

  @override
  State<OrdersPage> createState() {
    return _OrdersPageState();
  }
}

class _OrdersPageState extends State<OrdersPage> {
  late final OrdersViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = OrdersViewModel(ordersRepository: widget.ordersRepository);

    _viewModel.loadQueue();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
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
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, Widget? child) {
        final List<QueueOrder> orders = _viewModel.filteredOrders;

        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                color: AppColors.background,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 13),
                child: OrdersTopBar(
                  user: widget.user,
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
              Divider(height: 1, color: AppColors.outlineVariant.withAlpha(80)),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _viewModel.loadQueue,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: QueueMetricCard(
                              label: 'À traiter',
                              value: _viewModel.allReadyOrders.length,
                              unit: 'cmd',
                              valueColor: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: QueueMetricCard(
                              label: 'Temps moyen',
                              value: _viewModel.averageWaitingMinutes,
                              unit: 'min',
                              valueColor: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: QueueFilter.values.map((
                            QueueFilter filter,
                          ) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: QueueFilterButton(
                                label: _filterLabel(filter),
                                count: _viewModel.countForFilter(filter),
                                isSelected: _viewModel.selectedFilter == filter,
                                onPressed: () {
                                  _viewModel.selectFilter(filter);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_viewModel.errorMessage != null &&
                          _viewModel.hasOrders) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer.withAlpha(55),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.error.withAlpha(90),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _viewModel.errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
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
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Aucune commande ne correspond à ce filtre.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ...orders.map((QueueOrder order) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: QueueOrderCard(
                              order: order,
                              position: _viewModel.positionOf(order.id),
                              waitingMinutes: _viewModel.waitingMinutes(order),
                              isUrgent: _viewModel.isUrgent(order),
                              isProcessing: _viewModel.isTakingCharge(order.id),
                              onTakeCharge: () {
                                _confirmTakeCharge(order);
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
