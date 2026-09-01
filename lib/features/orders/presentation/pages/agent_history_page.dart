import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
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
import 'package:material_symbols_icons/symbols.dart';

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

  void _closeOpenedOrder() {
    if (_openedOrderId == null) return;
    setState(() => _openedOrderId = null);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _openedOrderId == null,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _openedOrderId != null) {
          _closeOpenedOrder();
        }
      },
      child: Scaffold(
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
                    onBack: _closeOpenedOrder,
                  );
                }
              }

              final List<QueueOrder> orders = switch (_tab) {
                0 => _viewModel.inProgressOrders,
                1 => _viewModel.successfulHistoryOrders,
                _ => _viewModel.failedOrders,
              };

              return RefreshIndicator(
                onRefresh: _viewModel.start,
                color: IzyTelColors.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                  children: [
                    Text(
                      'Historique',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontSize: IzyTelTypeScale.title2,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.25,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Retrouve tes commandes en cours, réussies et échouées.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: IzyTelColors.textSecondary,
                        fontSize: IzyTelTypeScale.label,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
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
                        const SizedBox(width: 7),
                        Expanded(
                          child: _HistoryTab(
                            label: 'Réussies',
                            count: _viewModel.successfulHistoryCount,
                            selected: _tab == 1,
                            onTap: () => setState(() => _tab = 1),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _HistoryTab(
                            label: 'Échecs',
                            count: _viewModel.failedCount,
                            selected: _tab == 2,
                            onTap: () => setState(() => _tab = 2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_viewModel.isLoading && orders.isEmpty)
                      const SizedBox(
                        height: 260,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (orders.isEmpty)
                      IzyTelSurface(
                        radius: IzyTelRadii.card,
                        child: Text(
                          _tab == 0
                              ? 'Aucune commande en cours.'
                              : (_tab == 1
                                    ? 'Aucune commande réussie.'
                                    : 'Aucun échec enregistré.'),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...orders.map(
                        (QueueOrder order) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _HistoryOrderCard(
                            order: order,
                            isCompleted: _tab != 0,
                            onTap: () =>
                                setState(() => _openedOrderId = order.id),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
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
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? IzyTelColors.primary : IzyTelColors.outline,
            ),
          ),
          child: Text(
            '$label  $count',
            maxLines: 1,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected
                  ? IzyTelColors.surface
                  : IzyTelColors.textSecondary,
              fontSize: IzyTelTypeScale.label,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryOrderCard extends StatelessWidget {
  const _HistoryOrderCard({
    required this.order,
    required this.isCompleted,
    required this.onTap,
  });

  final QueueOrder order;
  final bool isCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (order.network) {
      MobileNetwork.orange => IzyTelColors.orange,
      MobileNetwork.mtn => IzyTelColors.mtn,
      MobileNetwork.moov => IzyTelColors.moov,
    };
    final (String statusLabel, Color statusColor) = isCompleted
        ? switch (order.status) {
            QueueOrderStatus.failed => ('Échouée', IzyTelColors.error),
            QueueOrderStatus.refunded => ('Remboursée', IzyTelColors.success),
            _ => ('Réussie', IzyTelColors.success),
          }
        : switch (order.status) {
            QueueOrderStatus.onHold => ('En attente', IzyTelColors.warning),
            QueueOrderStatus.awaitingCustomerConfirmation => (
              'Réussie',
              IzyTelColors.success,
            ),
            _ => ('En traitement', IzyTelColors.primary),
          };

    return IzyTelSurface(
      onTap: onTap,
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: accent.withAlpha(16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  networkAsset(order.network),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  networkLabel(order.network),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: IzyTelColors.textSecondary,
                    fontSize: IzyTelTypeScale.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IzyTelStatusPill(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            order.offerLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: IzyTelColors.textPrimary,
              fontSize: IzyTelTypeScale.title3,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (order.status == QueueOrderStatus.failed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: IzyTelColors.errorSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: IzyTelColors.error.withAlpha(55)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Motif : ${_failureReasonHistoryLabel(order.failureReason)}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: IzyTelColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (order.observation?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      order.observation!.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: IzyTelColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: IzyTelColors.primarySoft.withAlpha(120),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Symbols.phone_iphone_rounded,
                  size: IzyTelIconSize.info,
                  color: IzyTelColors.textSecondary,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    formatIvorianPhone(order.beneficiaryPhone),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: IzyTelColors.textPrimary,
                      fontSize: IzyTelTypeScale.cardTitle,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatCfa(order.amount),
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: IzyTelColors.primaryStrong,
                    fontSize: IzyTelTypeScale.cardTitle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Symbols.chevron_right_rounded,
                  size: IzyTelIconSize.action,
                  color: IzyTelColors.textMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _failureReasonHistoryLabel(OrderFailureReason? reason) {
  if (reason == null) return 'Non renseigné';
  return switch (reason) {
    OrderFailureReason.incorrectNumber => 'Numéro incorrect',
    OrderFailureReason.networkUnavailable => 'Réseau indisponible',
    OrderFailureReason.offerUnavailable => 'Offre indisponible',
    OrderFailureReason.insufficientBalance => 'Solde insuffisant',
    OrderFailureReason.technicalError => 'Erreur technique',
    OrderFailureReason.incorrectPayment => 'Paiement incorrect',
    OrderFailureReason.other => 'Autre',
  };
}
