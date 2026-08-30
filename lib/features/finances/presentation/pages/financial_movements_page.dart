import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:cabine_flow/features/finances/domain/models/network_finance_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/network_finance_repository.dart';
import 'package:cabine_flow/features/finances/presentation/widgets/financial_ui.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _MovementFilter { all, incoming, outgoing }

enum _MovementKind { payment, refund, commission, network }

class FinancialMovementsPage extends StatefulWidget {
  const FinancialMovementsPage({
    super.key,
    required this.ordersRepository,
    required this.refundRepository,
    required this.commissionRepository,
    required this.networkFinanceRepository,
  });

  final OrdersRepository ordersRepository;
  final RefundRepository refundRepository;
  final CommissionRepository commissionRepository;
  final NetworkFinanceRepository networkFinanceRepository;

  @override
  State<FinancialMovementsPage> createState() => _FinancialMovementsPageState();
}

class _FinancialMovementsPageState extends State<FinancialMovementsPage> {
  _MovementFilter _filter = _MovementFilter.all;

  Stream<List<QueueOrder>> get _ordersStream {
    final OrdersRepository repository = widget.ordersRepository;
    if (repository is OrderHistoryRepository) {
      return (repository as OrderHistoryRepository).watchOrderHistory();
    }
    return repository.watchPaymentTrackingOrders();
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
          'Mouvements',
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
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<QueueOrder>> orderSnapshot,
              ) {
                return StreamBuilder<List<RefundCase>>(
                  stream: widget.refundRepository.watchAll(),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<RefundCase>> refundSnapshot,
                      ) {
                        return StreamBuilder<List<CommissionPayout>>(
                          stream: widget.commissionRepository.watchPayouts(),
                          builder:
                              (
                                BuildContext context,
                                AsyncSnapshot<List<CommissionPayout>>
                                payoutSnapshot,
                              ) {
                                return StreamBuilder<List<NetworkTransaction>>(
                                  stream: widget.networkFinanceRepository.watchTransactions(),
                                  builder:
                                      (
                                        BuildContext context,
                                        AsyncSnapshot<List<NetworkTransaction>> networkSnapshot,
                                      ) {
                                if (!orderSnapshot.hasData &&
                                    orderSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                final List<QueueOrder> orders =
                                    orderSnapshot.data ?? const <QueueOrder>[];
                                final List<RefundCase> refunds =
                                    refundSnapshot.data ?? const <RefundCase>[];
                                final List<CommissionPayout> payouts =
                                    payoutSnapshot.data ??
                                    const <CommissionPayout>[];
                                final List<NetworkTransaction> networkTransactions =
                                    networkSnapshot.data ??
                                    const <NetworkTransaction>[];
                                final Map<String, QueueOrder> orderById =
                                    <String, QueueOrder>{
                                      for (final QueueOrder order in orders)
                                        order.id: order,
                                    };

                                final List<_FinancialMovement> all =
                                    <_FinancialMovement>[
                                      ...orders
                                          .where(
                                            (QueueOrder order) =>
                                                order.paymentStatus ==
                                                    OrderPaymentStatus
                                                        .confirmed &&
                                                (order.paymentConfirmedAt !=
                                                        null ||
                                                    order.paidAt != null),
                                          )
                                          .map(
                                            (
                                              QueueOrder order,
                                            ) => _FinancialMovement(
                                              kind: _MovementKind.payment,
                                              amount: order.amount,
                                              date:
                                                  order.paymentConfirmedAt ??
                                                  order.paidAt!,
                                              title: 'Paiement confirmé',
                                              subtitle: order.offerLabel,
                                              reference:
                                                  order.paymentReference ??
                                                  order.reference,
                                              order: order,
                                            ),
                                          ),
                                      ...refunds
                                          .where(
                                            (RefundCase refund) =>
                                                refund.refundedAt != null,
                                          )
                                          .map(
                                            (RefundCase refund) =>
                                                _FinancialMovement(
                                                  kind: _MovementKind.refund,
                                                  amount: -refund.amount,
                                                  date: refund.refundedAt!,
                                                  title: 'Remboursement client',
                                                  subtitle: refund.clientName,
                                                  reference:
                                                      refund.refundReference ??
                                                      refund.orderReference,
                                                  order:
                                                      orderById[refund.orderId],
                                                ),
                                          ),
                                      ...payouts.map(
                                        (CommissionPayout payout) =>
                                            _FinancialMovement(
                                              kind: _MovementKind.commission,
                                              amount: -payout.amount,
                                              date: payout.paidAt,
                                              title: 'Commission agent',
                                              subtitle: payout.agentName,
                                              reference:
                                                  payout.paymentReference,
                                            ),
                                      ),
                                      ...networkTransactions.map(
                                        (NetworkTransaction transaction) =>
                                            _FinancialMovement(
                                              kind: _MovementKind.network,
                                              amount: transaction.isIncoming
                                                  ? transaction.amount
                                                  : -transaction.amount,
                                              date: transaction.createdAt,
                                              title: transaction.isIncoming
                                                  ? 'Entrée réseau ${transaction.network.label}'
                                                  : 'Sortie réseau ${transaction.network.label}',
                                              subtitle:
                                                  transaction.agentName ??
                                                  'Mouvement réseau',
                                              reference:
                                                  transaction.orderReference ??
                                                  transaction.id,
                                              order: transaction.orderId == null
                                                  ? null
                                                  : orderById[transaction.orderId],
                                            ),
                                      ),
                                    ]..sort(
                                      (
                                        _FinancialMovement a,
                                        _FinancialMovement b,
                                      ) => b.date.compareTo(a.date),
                                    );

                                final int incoming = all
                                    .where(
                                      (_FinancialMovement movement) =>
                                          movement.amount > 0,
                                    )
                                    .fold<int>(
                                      0,
                                      (
                                        int total,
                                        _FinancialMovement movement,
                                      ) => total + movement.amount,
                                    );
                                final int outgoing = all
                                    .where(
                                      (_FinancialMovement movement) =>
                                          movement.amount < 0,
                                    )
                                    .fold<int>(
                                      0,
                                      (
                                        int total,
                                        _FinancialMovement movement,
                                      ) => total + movement.amount.abs(),
                                    );
                                final List<_FinancialMovement> visible = all
                                    .where((movement) {
                                      switch (_filter) {
                                        case _MovementFilter.all:
                                          return true;
                                        case _MovementFilter.incoming:
                                          return movement.amount > 0;
                                        case _MovementFilter.outgoing:
                                          return movement.amount < 0;
                                      }
                                    })
                                    .toList(growable: false);

                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        4,
                                        20,
                                        12,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _MovementSummary(
                                                  label: 'Entrées',
                                                  value: formatCfa(incoming),
                                                  icon: Symbols
                                                      .south_west_rounded,
                                                  accent: IzyTelColors.success,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: _MovementSummary(
                                                  label: 'Sorties',
                                                  value: formatCfa(outgoing),
                                                  icon: Symbols
                                                      .north_east_rounded,
                                                  accent: IzyTelColors.error,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: FinanceFilterPill(
                                                  label: 'Tous',
                                                  count: all.length,
                                                  selected:
                                                      _filter ==
                                                      _MovementFilter.all,
                                                  onTap: () => setState(
                                                    () => _filter =
                                                        _MovementFilter.all,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 7),
                                              Expanded(
                                                child: FinanceFilterPill(
                                                  label: 'Entrées',
                                                  accent: IzyTelColors.success,
                                                  selected:
                                                      _filter ==
                                                      _MovementFilter.incoming,
                                                  onTap: () => setState(
                                                    () => _filter =
                                                        _MovementFilter
                                                            .incoming,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 7),
                                              Expanded(
                                                child: FinanceFilterPill(
                                                  label: 'Sorties',
                                                  accent: IzyTelColors.error,
                                                  selected:
                                                      _filter ==
                                                      _MovementFilter.outgoing,
                                                  onTap: () => setState(
                                                    () => _filter =
                                                        _MovementFilter
                                                            .outgoing,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: visible.isEmpty
                                          ? const SingleChildScrollView(
                                              child: FinanceEmptyState(
                                                icon: Symbols.swap_vert_rounded,
                                                title: 'Aucun mouvement',
                                                message:
                                                    'Les paiements, mouvements réseaux, remboursements et commissions apparaîtront ici.',
                                              ),
                                            )
                                          : ListView.separated(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    20,
                                                    2,
                                                    20,
                                                    28,
                                                  ),
                                              itemCount: visible.length,
                                              separatorBuilder: (_, _) =>
                                                  const Divider(
                                                    height: 1,
                                                    color: IzyTelColors.outline,
                                                  ),
                                              itemBuilder:
                                                  (
                                                    BuildContext context,
                                                    int index,
                                                  ) {
                                                    return _MovementRow(
                                                      movement: visible[index],
                                                    );
                                                  },
                                            ),
                                    ),
                                  ],
                                );
                                      },
                                );
                              },
                        );
                      },
                );
              },
        ),
      ),
    );
  }
}

class _FinancialMovement {
  const _FinancialMovement({
    required this.kind,
    required this.amount,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.reference,
    this.order,
  });

  final _MovementKind kind;
  final int amount;
  final DateTime date;
  final String title;
  final String subtitle;
  final String reference;
  final QueueOrder? order;
}

class _MovementSummary extends StatelessWidget {
  const _MovementSummary({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(IzyTelRadii.card),
        border: Border.all(color: IzyTelColors.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: IzyTelIconSize.info, color: accent),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                    fontSize: IzyTelTypeScale.micro,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontSize: IzyTelTypeScale.label,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final _FinancialMovement movement;

  bool get _incoming => movement.amount > 0;

  IconData get _icon {
    switch (movement.kind) {
      case _MovementKind.payment:
        return Symbols.receipt_long_rounded;
      case _MovementKind.refund:
        return Symbols.currency_exchange_rounded;
      case _MovementKind.commission:
        return Symbols.payments_rounded;
      case _MovementKind.network:
        return Symbols.cell_tower_rounded;
    }
  }

  Color get _accent {
    switch (movement.kind) {
      case _MovementKind.payment:
        return IzyTelColors.success;
      case _MovementKind.refund:
        return IzyTelColors.warning;
      case _MovementKind.commission:
        return IzyTelColors.primary;
      case _MovementKind.network:
        return IzyTelColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: _accent, size: IzyTelIconSize.action),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        movement.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: IzyTelColors.textPrimary,
                          fontSize: IzyTelTypeScale.label,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_incoming ? '+' : '-'}${formatCfa(movement.amount.abs())}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _incoming
                            ? IzyTelColors.success
                            : IzyTelColors.error,
                        fontSize: IzyTelTypeScale.label,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  movement.order == null
                      ? movement.subtitle
                      : '${movement.subtitle} · ${formatIvorianPhone(movement.order!.beneficiaryPhone)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                    fontSize: IzyTelTypeScale.micro,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        movement.reference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: IzyTelColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      financeDateTime(movement.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: IzyTelColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
