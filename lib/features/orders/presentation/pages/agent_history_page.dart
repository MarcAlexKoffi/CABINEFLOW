import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/pages/agent_order_detail_view.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/agent_orders_view_model.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';

class AgentHistoryPage extends StatefulWidget {
  const AgentHistoryPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    this.agentRepository,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final AgentRepository? agentRepository;

  @override
  State<AgentHistoryPage> createState() => _AgentHistoryPageState();
}

class _AgentHistoryPageState extends State<AgentHistoryPage> {
  late final AgentOrdersViewModel _viewModel;
  String? _openedOrderId;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = AgentOrdersViewModel(
      agentId: widget.user.id,
      ordersRepository: widget.ordersRepository,
      agentRepository: widget.agentRepository,
    );
    _viewModel.start();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (BuildContext context, Widget? child) {
            final String? openedId = _openedOrderId;
            if (openedId != null) {
              final QueueOrder? order = _viewModel.orderById(openedId);
              if (order != null) {
                return AgentOrderDetailView(
                  user: widget.user,
                  order: order,
                  viewModel: _viewModel,
                  onBack: () => setState(() => _openedOrderId = null),
                );
              }
            }

            final List<QueueOrder> orders = _tab == 0
                ? _viewModel.inProgressOrders
                : _viewModel.completedOrders;

            return RefreshIndicator(
              onRefresh: _viewModel.start,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
                children: [
                  Text(
                    'Historique',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Retrouve tes commandes en cours et terminées.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _HistoryTab(
                          label: 'En cours',
                          count: _viewModel.inProgressCount,
                          selected: _tab == 0,
                          onTap: () => setState(() => _tab = 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HistoryTab(
                          label: 'Terminées',
                          count: _viewModel.completedCount,
                          selected: _tab == 1,
                          onTap: () => setState(() => _tab = 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_viewModel.isLoading && orders.isEmpty)
                    const SizedBox(
                      height: 260,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (orders.isEmpty)
                    IzyTelSurface(
                      radius: 14,
                      child: Text(
                        _tab == 0
                            ? 'Aucune commande en cours.'
                            : 'Aucune commande terminée.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...orders.map(
                      (QueueOrder order) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: IzyTelSurface(
                          onTap: () =>
                              setState(() => _openedOrderId = order.id),
                          radius: 14,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: networkColor(
                                    order.network,
                                  ).withAlpha(16),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Image.asset(
                                  networkAsset(order.network),
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.offerLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(fontSize: 11),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      order.beneficiaryPhone,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(fontSize: 9.5),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatCfa(order.amount),
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: IzyTelColors.primaryStrong,
                                      fontSize: 10.5,
                                    ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: IzyTelColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? IzyTelColors.primary : IzyTelColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? IzyTelColors.primary : IzyTelColors.outline,
            ),
          ),
          child: Text(
            '$label  $count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? Colors.white : IzyTelColors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
