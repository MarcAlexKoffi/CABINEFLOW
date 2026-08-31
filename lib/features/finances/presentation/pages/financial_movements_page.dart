import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/models/network_finance_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/finance_operations_repository.dart';
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

enum _MovementKind {
  payment,
  refund,
  commission,
  network,
  supplier,
  credit,
  expense,
}

class FinancialMovementsPage extends StatefulWidget {
  const FinancialMovementsPage({
    super.key,
    required this.ordersRepository,
    required this.refundRepository,
    required this.commissionRepository,
    required this.networkFinanceRepository,
    required this.financeRepository,
  });

  final OrdersRepository ordersRepository;
  final RefundRepository refundRepository;
  final CommissionRepository commissionRepository;
  final NetworkFinanceRepository networkFinanceRepository;
  final FinanceOperationsRepository financeRepository;

  @override
  State<FinancialMovementsPage> createState() => _FinancialMovementsPageState();
}

class _FinancialMovementsPageState extends State<FinancialMovementsPage> {
  _MovementFilter _filter = _MovementFilter.all;
  late Future<List<_FinancialMovement>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Stream<List<QueueOrder>> get _ordersStream {
    final OrdersRepository repository = widget.ordersRepository;
    if (repository is OrderHistoryRepository) {
      return (repository as OrderHistoryRepository).watchOrderHistory();
    }
    return repository.watchPaymentTrackingOrders();
  }

  Future<List<_FinancialMovement>> _load() async {
    final List<QueueOrder> orders = await _ordersStream.first;
    final List<RefundCase> refunds = await widget.refundRepository
        .watchAll()
        .first;
    final List<CommissionPayout> payouts = await widget.commissionRepository
        .watchPayouts()
        .first;
    final List<NetworkTransaction> networks = await widget
        .networkFinanceRepository
        .watchTransactions()
        .first;
    final List<SupplierPayment> supplierPayments = await widget
        .financeRepository
        .watchSupplierPayments()
        .first;
    final List<CustomerCreditSettlement> settlements = await widget
        .financeRepository
        .watchCustomerCreditSettlements()
        .first;
    final List<FinanceExpense> expenses = await widget.financeRepository
        .watchExpenses()
        .first;
    final Map<String, QueueOrder> orderById = <String, QueueOrder>{
      for (final QueueOrder order in orders) order.id: order,
    };

    final List<_FinancialMovement> result =
        <_FinancialMovement>[
          ...orders
              .where(
                (QueueOrder order) =>
                    order.paymentStatus == OrderPaymentStatus.confirmed &&
                    (order.paymentConfirmedAt != null || order.paidAt != null),
              )
              .map(
                (QueueOrder order) => _FinancialMovement(
                  kind: _MovementKind.payment,
                  amount: order.amount,
                  date: order.paymentConfirmedAt ?? order.paidAt!,
                  title: 'Paiement client confirmé',
                  subtitle: order.offerLabel,
                  reference: order.paymentReference ?? order.reference,
                  order: order,
                ),
              ),
          ...refunds
              .where((RefundCase refund) => refund.refundedAt != null)
              .map(
                (RefundCase refund) => _FinancialMovement(
                  kind: _MovementKind.refund,
                  amount: -refund.amount,
                  date: refund.refundedAt!,
                  title: 'Remboursement client',
                  subtitle: refund.clientName,
                  reference: refund.refundReference ?? refund.orderReference,
                  order: orderById[refund.orderId],
                ),
              ),
          ...payouts.map(
            (CommissionPayout payout) => _FinancialMovement(
              kind: _MovementKind.commission,
              amount: -payout.amount,
              date: payout.paidAt,
              title: 'Commission Agent',
              subtitle: '${payout.agentName} · ${payout.paymentChannel}',
              reference: payout.paymentReference,
            ),
          ),
          ...networks.map(
            (NetworkTransaction transaction) => _FinancialMovement(
              kind: _MovementKind.network,
              amount: transaction.isIncoming
                  ? transaction.amount
                  : -transaction.amount,
              date: transaction.createdAt,
              title: transaction.isIncoming
                  ? 'Entrée réseau ${transaction.network.label}'
                  : 'Sortie réseau ${transaction.network.label}',
              subtitle:
                  transaction.supplierName ??
                  transaction.agentName ??
                  'Mouvement réseau',
              reference:
                  transaction.orderReference ??
                  transaction.supplierRechargeId ??
                  transaction.id,
              order: transaction.orderId == null
                  ? null
                  : orderById[transaction.orderId],
            ),
          ),
          ...supplierPayments.map(
            (SupplierPayment payment) => _FinancialMovement(
              kind: _MovementKind.supplier,
              amount: -payment.amount,
              date: payment.paidAt,
              title: 'Règlement fournisseur',
              subtitle: '${payment.supplierName} · ${payment.channel.label}',
              reference: payment.reference,
            ),
          ),
          ...settlements.map(
            (CustomerCreditSettlement payment) => _FinancialMovement(
              kind: _MovementKind.credit,
              amount: payment.amount,
              date: payment.paidAt,
              title: 'Règlement crédit client',
              subtitle: '${payment.clientName} · ${payment.channel.label}',
              reference: payment.reference,
            ),
          ),
          ...expenses.map(
            (FinanceExpense expense) => _FinancialMovement(
              kind: _MovementKind.expense,
              amount: -expense.amount,
              date: expense.spentAt,
              title: 'Dépense · ${expense.category.label}',
              subtitle: '${expense.description} · ${expense.channel.label}',
              reference: expense.reference ?? expense.id,
            ),
          ),
        ]..sort(
          (_FinancialMovement a, _FinancialMovement b) =>
              b.date.compareTo(a.date),
        );
    return List<_FinancialMovement>.unmodifiable(result);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        title: const Text(
          'Mouvements',
          style: TextStyle(
            fontSize: IzyTelTypeScale.title3,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Symbols.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<_FinancialMovement>>(
        future: _future,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<_FinancialMovement>> snapshot,
            ) {
              if (!snapshot.hasData &&
                  snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Impossible de charger les mouvements : ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final List<_FinancialMovement> all =
                  snapshot.data ?? const <_FinancialMovement>[];
              final int incoming = all
                  .where((_FinancialMovement item) => item.amount > 0)
                  .fold<int>(
                    0,
                    (int total, _FinancialMovement item) => total + item.amount,
                  );
              final int outgoing = all
                  .where((_FinancialMovement item) => item.amount < 0)
                  .fold<int>(
                    0,
                    (int total, _FinancialMovement item) =>
                        total + item.amount.abs(),
                  );
              final List<_FinancialMovement> visible = all
                  .where((_FinancialMovement item) {
                    switch (_filter) {
                      case _MovementFilter.all:
                        return true;
                      case _MovementFilter.incoming:
                        return item.amount > 0;
                      case _MovementFilter.outgoing:
                        return item.amount < 0;
                    }
                  })
                  .toList(growable: false);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _Summary(
                                label: 'Entrées',
                                value: formatCfa(incoming),
                                accent: IzyTelColors.success,
                                icon: Symbols.south_west_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _Summary(
                                label: 'Sorties',
                                value: formatCfa(outgoing),
                                accent: IzyTelColors.error,
                                icon: Symbols.north_east_rounded,
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
                                selected: _filter == _MovementFilter.all,
                                onTap: () => setState(
                                  () => _filter = _MovementFilter.all,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: FinanceFilterPill(
                                label: 'Entrées',
                                selected: _filter == _MovementFilter.incoming,
                                accent: IzyTelColors.success,
                                onTap: () => setState(
                                  () => _filter = _MovementFilter.incoming,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: FinanceFilterPill(
                                label: 'Sorties',
                                selected: _filter == _MovementFilter.outgoing,
                                accent: IzyTelColors.error,
                                onTap: () => setState(
                                  () => _filter = _MovementFilter.outgoing,
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
                                  'Les flux financiers et réseaux apparaîtront ici.',
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: IzyTelColors.outline,
                            ),
                            itemBuilder: (BuildContext context, int index) =>
                                _MovementRow(movement: visible[index]),
                          ),
                  ),
                ],
              );
            },
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

class _Summary extends StatelessWidget {
  const _Summary({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });
  final String label;
  final String value;
  final Color accent;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
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
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: IzyTelColors.textSecondary,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: IzyTelColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
      case _MovementKind.supplier:
        return Symbols.inventory_2_rounded;
      case _MovementKind.credit:
        return Symbols.request_quote_rounded;
      case _MovementKind.expense:
        return Symbols.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _incoming
        ? IzyTelColors.success
        : IzyTelColors.warning;
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
              color: accent.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: accent, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        movement.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: IzyTelColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${_incoming ? '+' : '-'}${formatCfa(movement.amount.abs())}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _incoming
                            ? IzyTelColors.success
                            : IzyTelColors.error,
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: IzyTelColors.textSecondary,
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
                        style: const TextStyle(
                          fontSize: 10,
                          color: IzyTelColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      financeDateTime(movement.date),
                      style: const TextStyle(
                        fontSize: 10,
                        color: IzyTelColors.textMuted,
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
