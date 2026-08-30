import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/finances/presentation/widgets/financial_ui.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart' hide formatIvorianPhone;
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/features/refunds/presentation/pages/refund_management_page.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _ReconciliationFilter { all, attention, coherent, refunded }

enum _ReconciliationState { attention, coherent, inProgress, refunded }

class FinancialReconciliationPage extends StatefulWidget {
  const FinancialReconciliationPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    required this.refundRepository,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final RefundRepository refundRepository;

  @override
  State<FinancialReconciliationPage> createState() =>
      _FinancialReconciliationPageState();
}

class _FinancialReconciliationPageState
    extends State<FinancialReconciliationPage> {
  _ReconciliationFilter _filter = _ReconciliationFilter.all;

  Stream<List<QueueOrder>> get _ordersStream {
    final OrdersRepository repository = widget.ordersRepository;
    if (repository is OrderHistoryRepository) {
      return (repository as OrderHistoryRepository).watchOrderHistory();
    }
    return repository.watchPaymentTrackingOrders();
  }

  OrderHistoryRepository? get _historyRepository {
    final OrdersRepository repository = widget.ordersRepository;
    if (repository is OrderHistoryRepository) {
      return repository as OrderHistoryRepository;
    }
    return null;
  }

  void _openRefund(RefundCase refund) {
    final OrderHistoryRepository? history = _historyRepository;
    if (history == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RefundDetailPage(
          user: widget.user,
          initialRefund: refund,
          repository: widget.refundRepository,
          orderHistoryRepository: history,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        backgroundColor: IzyTelColors.background,
        foregroundColor: IzyTelColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Rapprochements',
          style: TextStyle(
            fontSize: IzyTelTypeScale.title3,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<QueueOrder>>(
          stream: _ordersStream,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<QueueOrder>> orderSnapshot,
          ) {
            return StreamBuilder<List<RefundCase>>(
              stream: widget.refundRepository.watchAll(),
              builder: (
                BuildContext context,
                AsyncSnapshot<List<RefundCase>> refundSnapshot,
              ) {
                if (!orderSnapshot.hasData &&
                    orderSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final List<QueueOrder> orders =
                    orderSnapshot.data ?? const <QueueOrder>[];
                final List<RefundCase> refunds =
                    refundSnapshot.data ?? const <RefundCase>[];
                final Map<String, RefundCase> refundByOrder =
                    <String, RefundCase>{
                      for (final RefundCase refund in refunds)
                        refund.orderId: refund,
                    };

                final List<_ReconciliationItem> all = orders
                    .where(
                      (QueueOrder order) =>
                          order.paymentStatus == OrderPaymentStatus.confirmed ||
                          order.paymentStatus == OrderPaymentStatus.declared ||
                          order.status == QueueOrderStatus.refundPending ||
                          order.status == QueueOrderStatus.refunded,
                    )
                    .map(
                      (QueueOrder order) => _buildItem(
                        order,
                        refundByOrder[order.id],
                      ),
                    )
                    .toList(growable: false)
                  ..sort(
                    (_ReconciliationItem a, _ReconciliationItem b) =>
                        b.date.compareTo(a.date),
                  );

                final int attention = all
                    .where(
                      (_ReconciliationItem item) =>
                          item.state == _ReconciliationState.attention,
                    )
                    .length;
                final int coherent = all
                    .where(
                      (_ReconciliationItem item) =>
                          item.state == _ReconciliationState.coherent,
                    )
                    .length;
                final int refunded = all
                    .where(
                      (_ReconciliationItem item) =>
                          item.state == _ReconciliationState.refunded,
                    )
                    .length;
                final List<_ReconciliationItem> visible = all
                    .where(_matchesFilter)
                    .toList(growable: false);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: IzyTelColors.primarySoft,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Symbols.info_rounded,
                                  color: IzyTelColors.primary,
                                  size: IzyTelIconSize.info,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Contrôle interne commandes, paiements et remboursements. Le rapprochement bancaire Wave sera branché lorsque les données API seront disponibles.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: IzyTelColors.textSecondary,
                                          fontSize: IzyTelTypeScale.micro,
                                          height: 1.35,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 34,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                FinanceFilterPill(
                                  label: 'Tous',
                                  count: all.length,
                                  selected:
                                      _filter == _ReconciliationFilter.all,
                                  onTap: () => setState(
                                    () => _filter = _ReconciliationFilter.all,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                FinanceFilterPill(
                                  label: 'À vérifier',
                                  count: attention,
                                  accent: IzyTelColors.warning,
                                  selected: _filter ==
                                      _ReconciliationFilter.attention,
                                  onTap: () => setState(
                                    () => _filter =
                                        _ReconciliationFilter.attention,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                FinanceFilterPill(
                                  label: 'Cohérents',
                                  count: coherent,
                                  accent: IzyTelColors.success,
                                  selected: _filter ==
                                      _ReconciliationFilter.coherent,
                                  onTap: () => setState(
                                    () => _filter =
                                        _ReconciliationFilter.coherent,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                FinanceFilterPill(
                                  label: 'Remboursés',
                                  count: refunded,
                                  selected: _filter ==
                                      _ReconciliationFilter.refunded,
                                  onTap: () => setState(
                                    () => _filter =
                                        _ReconciliationFilter.refunded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: visible.isEmpty
                          ? const SingleChildScrollView(
                              child: FinanceEmptyState(
                                icon: Symbols.rule_rounded,
                                title: 'Aucun élément dans ce filtre',
                                message:
                                    'Les contrôles de cohérence apparaîtront ici au fur et à mesure des transactions.',
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (BuildContext context, int index) {
                                final _ReconciliationItem item = visible[index];
                                return _ReconciliationCard(
                                  item: item,
                                  onTap: item.refund != null && _historyRepository != null
                                      ? () => _openRefund(item.refund!)
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  bool _matchesFilter(_ReconciliationItem item) {
    switch (_filter) {
      case _ReconciliationFilter.all:
        return true;
      case _ReconciliationFilter.attention:
        return item.state == _ReconciliationState.attention;
      case _ReconciliationFilter.coherent:
        return item.state == _ReconciliationState.coherent ||
            item.state == _ReconciliationState.inProgress;
      case _ReconciliationFilter.refunded:
        return item.state == _ReconciliationState.refunded;
    }
  }

  _ReconciliationItem _buildItem(QueueOrder order, RefundCase? refund) {
    final DateTime date =
        refund?.updatedAt ??
        order.completedAt ??
        order.paymentConfirmedAt ??
        order.paidAt ??
        order.paymentDeclaredAt ??
        order.createdAt;

    if (order.paymentStatus == OrderPaymentStatus.declared) {
      return _ReconciliationItem(
        order: order,
        refund: refund,
        state: _ReconciliationState.attention,
        label: 'Paiement à vérifier',
        description: 'Le client a déclaré le paiement mais il n’est pas encore confirmé.',
        date: date,
      );
    }

    final bool requiresRefund =
        order.status == QueueOrderStatus.failed ||
        order.status == QueueOrderStatus.refundPending ||
        order.status == QueueOrderStatus.refunded;

    if (requiresRefund) {
      if (refund == null) {
        return _ReconciliationItem(
          order: order,
          refund: null,
          state: _ReconciliationState.attention,
          label: 'Remboursement à contrôler',
          description: 'La commande nécessite un contrôle mais aucun dossier rapproché n’est disponible.',
          date: date,
        );
      }
      if (refund.status == RefundStatus.reconciled) {
        return _ReconciliationItem(
          order: order,
          refund: refund,
          state: _ReconciliationState.refunded,
          label: 'Remboursement rapproché',
          description: 'Paiement, remboursement et dossier interne sont cohérents.',
          date: date,
        );
      }
      return _ReconciliationItem(
        order: order,
        refund: refund,
        state: _ReconciliationState.attention,
        label: refund.status == RefundStatus.refunded
            ? 'Remboursement à rapprocher'
            : 'Remboursement en cours',
        description: 'Le dossier de remboursement n’est pas encore totalement rapproché.',
        date: date,
      );
    }

    if (order.status == QueueOrderStatus.completed) {
      return _ReconciliationItem(
        order: order,
        refund: refund,
        state: _ReconciliationState.coherent,
        label: 'Transaction cohérente',
        description: 'Paiement confirmé et commande terminée.',
        date: date,
      );
    }

    return _ReconciliationItem(
      order: order,
      refund: refund,
      state: _ReconciliationState.inProgress,
      label: 'Traitement en cours',
      description: 'Le paiement est confirmé et la commande suit son traitement normal.',
      date: date,
    );
  }
}

class _ReconciliationItem {
  const _ReconciliationItem({
    required this.order,
    required this.refund,
    required this.state,
    required this.label,
    required this.description,
    required this.date,
  });

  final QueueOrder order;
  final RefundCase? refund;
  final _ReconciliationState state;
  final String label;
  final String description;
  final DateTime date;
}

class _ReconciliationCard extends StatelessWidget {
  const _ReconciliationCard({required this.item, this.onTap});

  final _ReconciliationItem item;
  final VoidCallback? onTap;

  Color get _accent {
    switch (item.state) {
      case _ReconciliationState.attention:
        return IzyTelColors.warning;
      case _ReconciliationState.coherent:
        return IzyTelColors.success;
      case _ReconciliationState.inProgress:
        return IzyTelColors.primary;
      case _ReconciliationState.refunded:
        return IzyTelColors.moov;
    }
  }

  IconData get _icon {
    switch (item.state) {
      case _ReconciliationState.attention:
        return Symbols.warning_rounded;
      case _ReconciliationState.coherent:
        return Symbols.check_circle_rounded;
      case _ReconciliationState.inProgress:
        return Symbols.schedule_rounded;
      case _ReconciliationState.refunded:
        return Symbols.currency_exchange_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final QueueOrder order = item.order;
    return IzyTelSurface(
      radius: IzyTelRadii.card,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _NetworkLogo(network: order.network),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  networkLabel(order.network),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontSize: IzyTelTypeScale.label,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                financeRelativeTime(item.date),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: IzyTelColors.textMuted,
                  fontSize: IzyTelTypeScale.micro,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            order.offerLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: IzyTelColors.textPrimary,
              fontSize: IzyTelTypeScale.cardTitle,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatIvorianPhone(order.beneficiaryPhone),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontSize: IzyTelTypeScale.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatCfa(order.amount),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: IzyTelColors.primaryStrong,
                  fontSize: IzyTelTypeScale.cardTitle,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accent.withAlpha(18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icon, size: IzyTelIconSize.info, color: _accent),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: _accent,
                          fontSize: IzyTelTypeScale.label,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: IzyTelColors.textSecondary,
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  order.reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
              if (item.refund != null)
                Text(
                  item.refund!.status.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  Symbols.chevron_right_rounded,
                  color: IzyTelColors.textMuted,
                  size: IzyTelIconSize.info,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _NetworkLogo extends StatelessWidget {
  const _NetworkLogo({required this.network});
  final MobileNetwork network;

  String get _asset => switch (network) {
        MobileNetwork.orange => 'assets/brands/operators/orange_ci.png',
        MobileNetwork.mtn => 'assets/brands/operators/mtn_ci.png',
        MobileNetwork.moov => 'assets/brands/operators/moov_africa_ci.png',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: IzyTelColors.surfaceMuted,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Image.asset(_asset, fit: BoxFit.contain),
    );
  }
}
