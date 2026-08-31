import 'dart:async';

import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:cabine_flow/features/commissions/presentation/pages/commission_management_page.dart';
import 'package:cabine_flow/features/finances/data/repositories/fake_finance_operations_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/firestore_finance_operations_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/fake_network_finance_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/firestore_network_finance_repository.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/models/network_finance_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/finance_operations_repository.dart';
import 'package:cabine_flow/features/finances/domain/repositories/network_finance_repository.dart';
import 'package:cabine_flow/features/finances/domain/services/network_finance_calculator.dart';
import 'package:cabine_flow/features/finances/presentation/pages/customer_credits_page.dart';
import 'package:cabine_flow/features/finances/presentation/pages/daily_financial_closing_page.dart';
import 'package:cabine_flow/features/finances/presentation/pages/finance_expenses_page.dart';
import 'package:cabine_flow/features/finances/presentation/pages/financial_movements_page.dart';
import 'package:cabine_flow/features/finances/presentation/pages/financial_reconciliation_page.dart';
import 'package:cabine_flow/features/finances/presentation/pages/supplier_finance_page.dart';
import 'package:cabine_flow/features/finances/presentation/pages/wave_cash_page.dart';
import 'package:cabine_flow/features/finances/presentation/pages/working_capital_page.dart';
import 'package:cabine_flow/features/finances/presentation/widgets/financial_ui.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/refunds/data/repositories/fake_refund_repository.dart';
import 'package:cabine_flow/features/refunds/data/repositories/firestore_refund_repository.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/features/refunds/presentation/pages/refund_management_page.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class FinancesPage extends StatefulWidget {
  const FinancesPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    required this.commissionRepository,
    required this.agentRepository,
    required this.onOpenPayments,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final CommissionRepository commissionRepository;
  final AgentRepository agentRepository;
  final VoidCallback onOpenPayments;

  @override
  State<FinancesPage> createState() => _FinancesPageState();
}

class _FinancesPageState extends State<FinancesPage> {
  late final RefundRepository _refundRepository;
  late final NetworkFinanceRepository _networkFinanceRepository;
  late final FinanceOperationsRepository _financeOperationsRepository;

  OrderHistoryRepository? get _historyRepository {
    final OrdersRepository repository = widget.ordersRepository;
    if (repository is OrderHistoryRepository) {
      return repository as OrderHistoryRepository;
    }
    return null;
  }

  Stream<List<QueueOrder>> get _ordersStream {
    final OrderHistoryRepository? history = _historyRepository;
    return history?.watchOrderHistory() ??
        widget.ordersRepository.watchPaymentTrackingOrders();
  }

  @override
  void initState() {
    super.initState();
    _refundRepository = Firebase.apps.isNotEmpty
        ? FirestoreRefundRepository()
        : FakeRefundRepository();
    _networkFinanceRepository = Firebase.apps.isNotEmpty
        ? FirestoreNetworkFinanceRepository()
        : FakeNetworkFinanceRepository();
    _financeOperationsRepository = Firebase.apps.isNotEmpty
        ? FirestoreFinanceOperationsRepository()
        : FakeFinanceOperationsRepository();
  }

  @override
  void dispose() {
    final RefundRepository repository = _refundRepository;
    if (repository is FakeRefundRepository) {
      unawaited(repository.dispose());
    }
    final NetworkFinanceRepository networkRepository =
        _networkFinanceRepository;
    if (networkRepository is FakeNetworkFinanceRepository) {
      unawaited(networkRepository.dispose());
    }
    final FinanceOperationsRepository financeRepository =
        _financeOperationsRepository;
    if (financeRepository is FakeFinanceOperationsRepository) {
      unawaited(financeRepository.dispose());
    }
    super.dispose();
  }

  bool _isToday(DateTime? value) {
    if (value == null) return false;
    final DateTime now = DateTime.now();
    return value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
  }

  bool _isConfirmed(QueueOrder order) {
    return order.paymentStatus == OrderPaymentStatus.confirmed &&
        (order.paymentConfirmedAt != null || order.paidAt != null);
  }

  DateTime? _paymentDate(QueueOrder order) =>
      order.paymentConfirmedAt ?? order.paidAt;

  int _confirmedAmountToday(List<QueueOrder> orders) {
    return orders
        .where(
          (QueueOrder order) =>
              _isConfirmed(order) && _isToday(_paymentDate(order)),
        )
        .fold<int>(0, (int total, QueueOrder order) => total + order.amount);
  }

  int _refundsPaidToday(List<RefundCase> refunds) {
    return refunds
        .where((RefundCase refund) => _isToday(refund.refundedAt))
        .fold<int>(0, (int total, RefundCase refund) => total + refund.amount);
  }

  int _commissionPayoutsToday(List<CommissionPayout> payouts) {
    return payouts
        .where((CommissionPayout payout) => _isToday(payout.paidAt))
        .fold<int>(
          0,
          (int total, CommissionPayout payout) => total + payout.amount,
        );
  }

  int _creditSettlementsToday(
    List<CustomerCreditSettlement> settlements, {
    FinancePaymentChannel? channel,
  }) {
    return settlements.where((CustomerCreditSettlement settlement) {
      return _isToday(settlement.paidAt) &&
          (channel == null || settlement.channel == channel);
    }).fold<int>(
      0,
      (int total, CustomerCreditSettlement settlement) =>
          total + settlement.amount,
    );
  }

  int _supplierPaymentsToday(List<SupplierPayment> payments) {
    return payments
        .where((SupplierPayment payment) => _isToday(payment.paidAt))
        .fold<int>(
          0,
          (int total, SupplierPayment payment) => total + payment.amount,
        );
  }

  int _expensesToday(List<FinanceExpense> expenses) {
    return expenses
        .where((FinanceExpense expense) => _isToday(expense.spentAt))
        .fold<int>(
          0,
          (int total, FinanceExpense expense) => total + expense.amount,
        );
  }

  void _openRefunds() {
    final OrderHistoryRepository? history = _historyRepository;
    if (history == null) {
      _showUnavailable(
        'L’historique des commandes est requis pour les remboursements.',
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RefundManagementPage(
          user: widget.user,
          repository: _refundRepository,
          orderHistoryRepository: history,
        ),
      ),
    );
  }

  void _openCommissions() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommissionManagementPage(
          user: widget.user,
          repository: widget.commissionRepository,
          agentRepository: widget.agentRepository,
        ),
      ),
    );
  }

  void _openReconciliation() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FinancialReconciliationPage(
          user: widget.user,
          ordersRepository: widget.ordersRepository,
          refundRepository: _refundRepository,
        ),
      ),
    );
  }

  void _openMovements() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FinancialMovementsPage(
          ordersRepository: widget.ordersRepository,
          refundRepository: _refundRepository,
          commissionRepository: widget.commissionRepository,
          networkFinanceRepository: _networkFinanceRepository,
          financeRepository: _financeOperationsRepository,
        ),
      ),
    );
  }


  void _openSuppliers() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SupplierFinancePage(
          user: widget.user,
          repository: _financeOperationsRepository,
          agentRepository: widget.agentRepository,
        ),
      ),
    );
  }

  void _openWaveCash() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WaveCashPage(
          user: widget.user,
          ordersRepository: widget.ordersRepository,
          refundRepository: _refundRepository,
          commissionRepository: widget.commissionRepository,
          financeRepository: _financeOperationsRepository,
        ),
      ),
    );
  }

  void _openCustomerCredits() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CustomerCreditsPage(
          user: widget.user,
          repository: _financeOperationsRepository,
          ordersRepository: widget.ordersRepository,
        ),
      ),
    );
  }

  void _openExpenses() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FinanceExpensesPage(
          user: widget.user,
          repository: _financeOperationsRepository,
        ),
      ),
    );
  }

  void _openWorkingCapital() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WorkingCapitalPage(
          ordersRepository: widget.ordersRepository,
          refundRepository: _refundRepository,
          commissionRepository: widget.commissionRepository,
          agentRepository: widget.agentRepository,
          networkFinanceRepository: _networkFinanceRepository,
          financeRepository: _financeOperationsRepository,
        ),
      ),
    );
  }

  void _openDailyClosing() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DailyFinancialClosingPage(
          user: widget.user,
          ordersRepository: widget.ordersRepository,
          refundRepository: _refundRepository,
          commissionRepository: widget.commissionRepository,
          agentRepository: widget.agentRepository,
          networkFinanceRepository: _networkFinanceRepository,
          financeRepository: _financeOperationsRepository,
        ),
      ),
    );
  }

  void _showUnavailable(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: StreamBuilder<List<QueueOrder>>(
        stream: _ordersStream,
        builder: (BuildContext context, AsyncSnapshot<List<QueueOrder>> orderSnapshot) {
          return StreamBuilder<List<RefundCase>>(
            stream: _refundRepository.watchAll(),
            builder: (BuildContext context, AsyncSnapshot<List<RefundCase>> refundSnapshot) {
              return StreamBuilder<List<CommissionAccount>>(
                stream: widget.commissionRepository.watchAccounts(),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<CommissionAccount>> accountSnapshot,
                    ) {
                      return StreamBuilder<List<CommissionPayout>>(
                        stream: widget.commissionRepository.watchPayouts(),
                        builder:
                            (
                              BuildContext context,
                              AsyncSnapshot<List<CommissionPayout>>
                              payoutSnapshot,
                            ) {
                              return StreamBuilder<List<CustomerCreditSettlement>>(
                                stream: _financeOperationsRepository.watchCustomerCreditSettlements(),
                                builder:
                                    (
                                      BuildContext context,
                                      AsyncSnapshot<List<CustomerCreditSettlement>> settlementSnapshot,
                                    ) {
                                  return StreamBuilder<List<SupplierPayment>>(
                                    stream: _financeOperationsRepository.watchSupplierPayments(),
                                    builder:
                                        (
                                          BuildContext context,
                                          AsyncSnapshot<List<SupplierPayment>> supplierPaymentSnapshot,
                                        ) {
                                      return StreamBuilder<List<FinanceExpense>>(
                                        stream: _financeOperationsRepository.watchExpenses(),
                                        builder:
                                            (
                                              BuildContext context,
                                              AsyncSnapshot<List<FinanceExpense>> expenseSnapshot,
                                            ) {
                                              return StreamBuilder<List<NetworkTransaction>>(
                                stream: _networkFinanceRepository.watchTransactions(),
                                builder:
                                    (
                                      BuildContext context,
                                      AsyncSnapshot<List<NetworkTransaction>> networkSnapshot,
                                    ) {
                              final List<QueueOrder> orders =
                                  orderSnapshot.data ?? const <QueueOrder>[];
                              final List<RefundCase> refunds =
                                  refundSnapshot.data ?? const <RefundCase>[];
                              final List<CommissionAccount> accounts =
                                  accountSnapshot.data ??
                                  const <CommissionAccount>[];
                              final List<CommissionPayout> payouts =
                                  payoutSnapshot.data ??
                                  const <CommissionPayout>[];
                              final List<NetworkTransaction> networkTransactions =
                                  networkSnapshot.data ??
                                  const <NetworkTransaction>[];
                              final List<CustomerCreditSettlement> creditSettlements =
                                  settlementSnapshot.data ??
                                  const <CustomerCreditSettlement>[];
                              final List<SupplierPayment> supplierPayments =
                                  supplierPaymentSnapshot.data ??
                                  const <SupplierPayment>[];
                              final List<FinanceExpense> expenses =
                                  expenseSnapshot.data ??
                                  const <FinanceExpense>[];

                              final bool initialLoading =
                                  !orderSnapshot.hasData &&
                                  !refundSnapshot.hasData &&
                                  orderSnapshot.connectionState ==
                                      ConnectionState.waiting;
                              if (initialLoading) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final int confirmedPaymentsToday =
                                  _confirmedAmountToday(orders);
                              final int creditSettlementsToday =
                                  _creditSettlementsToday(creditSettlements);
                              final int waveCreditSettlementsToday =
                                  _creditSettlementsToday(
                                    creditSettlements,
                                    channel: FinancePaymentChannel.wave,
                                  );
                              final int incomeToday =
                                  confirmedPaymentsToday + creditSettlementsToday;
                              final int waveToday =
                                  confirmedPaymentsToday + waveCreditSettlementsToday;
                              final int refundsToday = _refundsPaidToday(
                                refunds,
                              );
                              final int commissionsToday =
                                  _commissionPayoutsToday(payouts);
                              final int supplierPaymentsToday =
                                  _supplierPaymentsToday(supplierPayments);
                              final int expensesToday = _expensesToday(expenses);
                              final int netToday =
                                  incomeToday -
                                  refundsToday -
                                  commissionsToday -
                                  supplierPaymentsToday -
                                  expensesToday;
                              final int refundPending = refunds
                                  .where((RefundCase value) => value.isActive)
                                  .fold<int>(
                                    0,
                                    (int total, RefundCase value) =>
                                        total + value.amount,
                                  );
                              final int refundPendingCount = refunds
                                  .where((RefundCase value) => value.isActive)
                                  .length;
                              final int commissionsOutstanding = accounts
                                  .fold<int>(
                                    0,
                                    (int total, CommissionAccount account) =>
                                        total +
                                        account.balance
                                            .clamp(0, account.earnedTotal)
                                            .toInt(),
                                  );

                              return ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  18,
                                  20,
                                  32,
                                ),
                                children: [
                                  Text(
                                    'Finances',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: IzyTelColors.textPrimary,
                                          fontSize: IzyTelTypeScale.title2,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -.45,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Vue d’ensemble de l’activité financière IzyTel.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: IzyTelColors.textSecondary,
                                          fontSize: IzyTelTypeScale.label,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                  const SizedBox(height: 18),
                                  _FinanceHero(
                                    incomeToday: incomeToday,
                                    creditSettlementsToday: creditSettlementsToday,
                                    netToday: netToday,
                                    refundsToday: refundsToday,
                                    commissionsToday: commissionsToday,
                                    supplierPaymentsToday: supplierPaymentsToday,
                                    expensesToday: expensesToday,
                                  ),
                                  const SizedBox(height: 20),
                                  const IzyTelSectionHeader(
                                    title: 'À surveiller',
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: FinancialMetricCard(
                                          label: 'Remboursements ouverts',
                                          value: formatCfa(refundPending),
                                          caption:
                                              '$refundPendingCount dossier${refundPendingCount > 1 ? 's' : ''}',
                                          icon:
                                              Symbols.currency_exchange_rounded,
                                          accent: refundPending > 0
                                              ? IzyTelColors.warning
                                              : IzyTelColors.success,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: FinancialMetricCard(
                                          label: 'Commissions à payer',
                                          value: formatCfa(
                                            commissionsOutstanding,
                                          ),
                                          caption: commissionsOutstanding > 0
                                              ? 'Solde agents'
                                              : 'À jour',
                                          icon: Symbols
                                              .account_balance_wallet_rounded,
                                          accent: commissionsOutstanding > 0
                                              ? IzyTelColors.error
                                              : IzyTelColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  const IzyTelSectionHeader(
                                    title: 'Fonds de roulement',
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Soldes réseaux disponibles, montants engagés et encaissements Wave du jour.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: IzyTelColors.textMuted,
                                          fontSize: IzyTelTypeScale.micro,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  _NetworkCapacitySection(
                                    agentRepository: widget.agentRepository,
                                    orders: orders,
                                    transactions: networkTransactions,
                                    waveToday: waveToday,
                                  ),
                                  const SizedBox(height: 22),
                                  const IzyTelSectionHeader(
                                    title: 'Gestion financière',
                                  ),
                                  const SizedBox(height: 10),
                                  FinanceActionTile(
                                    icon: Symbols.receipt_long_rounded,
                                    title: 'Paiements',
                                    subtitle:
                                        'Vérifier les déclarations et confirmer les encaissements.',
                                    onTap: widget.onOpenPayments,
                                  ),
                                  const SizedBox(height: 8),
                                  FinanceActionTile(
                                    icon: Symbols.currency_exchange_rounded,
                                    title: 'Remboursements',
                                    subtitle:
                                        'Valider, effectuer et tracer les remboursements clients.',
                                    accent: IzyTelColors.warning,
                                    badge: refundPendingCount > 0
                                        ? '$refundPendingCount'
                                        : null,
                                    onTap: _openRefunds,
                                  ),
                                  const SizedBox(height: 8),
                                  FinanceActionTile(
                                    icon: Symbols.payments_rounded,
                                    title: 'Commissions',
                                    subtitle:
                                        'Suivre les commissions acquises et les paiements agents.',
                                    accent: IzyTelColors.success,
                                    badge: commissionsOutstanding > 0
                                        ? formatCfa(commissionsOutstanding)
                                        : null,
                                    onTap: _openCommissions,
                                  ),
                                  const SizedBox(height: 8),
                                  FinanceActionTile(
                                    icon: Symbols.inventory_2_rounded,
                                    title: 'Fournisseurs',
                                    subtitle:
                                        'Enregistrer les recharges, bonus et règlements fournisseurs.',
                                    onTap: _openSuppliers,
                                  ),
                                  const SizedBox(height: 8),
                                  FinanceActionTile(
                                    icon: Symbols.account_balance_wallet_rounded,
                                    title: 'Caisse Wave',
                                    subtitle:
                                        'Suivre le solde théorique et tous les flux Wave.',
                                    accent: IzyTelColors.wave,
                                    onTap: _openWaveCash,
                                  ),
                                  const SizedBox(height: 8),
                                  FinanceActionTile(
                                    icon: Symbols.request_quote_rounded,
                                    title: 'Crédits clients',
                                    subtitle:
                                        'Suivre les montants dus et les règlements ultérieurs.',
                                    accent: IzyTelColors.warning,
                                    onTap: _openCustomerCredits,
                                  ),
                                  const SizedBox(height: 8),
                                  FinanceActionTile(
                                    icon: Symbols.receipt_long_rounded,
                                    title: 'Dépenses',
                                    subtitle:
                                        'Tracer transport, internet et autres charges.',
                                    accent: IzyTelColors.warning,
                                    onTap: _openExpenses,
                                  ),
                                  const SizedBox(height: 8),
                                  FinanceActionTile(
                                    icon: Symbols.savings_rounded,
                                    title: 'Fonds de roulement',
                                    subtitle:
                                        'Mesurer les liquidités, engagements, dettes et créances.',
                                    onTap: _openWorkingCapital,
                                  ),
                                  const SizedBox(height: 8),
                                  FinanceActionTile(
                                    icon: Symbols.calendar_month_rounded,
                                    title: 'Clôture journalière',
                                    subtitle:
                                        'Figer les chiffres du jour, le solde Wave et les écarts.',
                                    onTap: _openDailyClosing,
                                  ),
                                  const SizedBox(height: 8),
                                  FinanceActionTile(
                                    icon: Symbols.rule_rounded,
                                    title: 'Rapprochements',
                                    subtitle:
                                        'Contrôler toute la chaîne paiement, traitement et finance.',
                                    accent: IzyTelColors.primary,
                                    badge: 'Contrôle 14A',
                                    onTap: _openReconciliation,
                                  ),
                                  const SizedBox(height: 8),
                                  FinanceActionTile(
                                    icon: Symbols.swap_vert_rounded,
                                    title: 'Mouvements',
                                    subtitle:
                                        'Consulter les entrées et sorties financières dans un journal unique.',
                                    onTap: _openMovements,
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
                              );
                            },
                      );
                    },
              );
            },
          );
        },
      ),
    );
  }
}

class _FinanceHero extends StatelessWidget {
  const _FinanceHero({
    required this.incomeToday,
    required this.creditSettlementsToday,
    required this.netToday,
    required this.refundsToday,
    required this.commissionsToday,
    required this.supplierPaymentsToday,
    required this.expensesToday,
  });

  final int incomeToday;
  final int creditSettlementsToday;
  final int netToday;
  final int refundsToday;
  final int commissionsToday;
  final int supplierPaymentsToday;
  final int expensesToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[IzyTelColors.primary, IzyTelColors.primaryStrong],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(IzyTelRadii.largeCard),
        boxShadow: [
          BoxShadow(
            color: IzyTelColors.primary.withAlpha(40),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Encaissements aujourd’hui',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: IzyTelColors.surface.withAlpha(225),
                    fontSize: IzyTelTypeScale.label,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: IzyTelColors.surface.withAlpha(26),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Symbols.account_balance_wallet_rounded,
                  color: IzyTelColors.surface,
                  size: 23,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatCfaFull(incomeToday),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: IzyTelColors.surface,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -.7,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroTag(
                label: 'Net ${formatCfa(netToday)}',
                icon: netToday >= 0
                    ? Symbols.trending_up_rounded
                    : Symbols.trending_down_rounded,
              ),
              if (creditSettlementsToday > 0)
                _HeroTag(
                  label: '+ ${formatCfa(creditSettlementsToday)} crédits encaissés',
                  icon: Symbols.savings_rounded,
                ),
              if (refundsToday > 0)
                _HeroTag(
                  label: '- ${formatCfa(refundsToday)} remboursés',
                  icon: Symbols.currency_exchange_rounded,
                ),
              if (commissionsToday > 0)
                _HeroTag(
                  label: '- ${formatCfa(commissionsToday)} commissions',
                  icon: Symbols.payments_rounded,
                ),
              if (supplierPaymentsToday > 0)
                _HeroTag(
                  label: '- ${formatCfa(supplierPaymentsToday)} fournisseurs',
                  icon: Symbols.inventory_2_rounded,
                ),
              if (expensesToday > 0)
                _HeroTag(
                  label: '- ${formatCfa(expensesToday)} dépenses',
                  icon: Symbols.receipt_long_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: IzyTelColors.surface.withAlpha(28),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: IzyTelColors.surface, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: IzyTelColors.surface,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkCapacitySection extends StatelessWidget {
  const _NetworkCapacitySection({
    required this.agentRepository,
    required this.orders,
    required this.transactions,
    required this.waveToday,
  });

  final AgentRepository agentRepository;
  final List<QueueOrder> orders;
  final List<NetworkTransaction> transactions;
  final int waveToday;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AgentDirectoryEntry>>(
      stream: agentRepository.watchAgents(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<AgentDirectoryEntry>> snapshot,
          ) {
            final List<AgentDirectoryEntry> agents =
                snapshot.data ?? const <AgentDirectoryEntry>[];
            final Map<AgentNetwork, NetworkFundSnapshot> funds =
                NetworkFinanceCalculator.calculate(
                  agents: agents,
                  orders: orders,
                  transactions: transactions,
                );

            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 360;
                final double width = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: width,
                      child: _NetworkFundCard(
                        label: 'Orange',
                        snapshot: funds[AgentNetwork.orange]!,
                        asset: 'assets/brands/operators/orange_ci.png',
                        accent: IzyTelColors.orange,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _NetworkFundCard(
                        label: 'MTN',
                        snapshot: funds[AgentNetwork.mtn]!,
                        asset: 'assets/brands/operators/mtn_ci.png',
                        accent: IzyTelColors.mtnText,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _NetworkFundCard(
                        label: 'Moov Africa',
                        snapshot: funds[AgentNetwork.moov]!,
                        asset: 'assets/brands/operators/moov_africa_ci.png',
                        accent: IzyTelColors.moov,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _NetworkFundCard.wave(
                        amount: waveToday,
                        asset: 'assets/images/wave_logo.png',
                        accent: IzyTelColors.wave,
                      ),
                    ),
                  ],
                );
              },
            );
          },
    );
  }
}

class _NetworkFundCard extends StatelessWidget {
  const _NetworkFundCard({
    required this.label,
    required this.snapshot,
    required this.asset,
    required this.accent,
  }) : waveAmount = null;

  const _NetworkFundCard.wave({
    required int amount,
    required this.asset,
    required this.accent,
  }) : label = 'Wave',
       snapshot = null,
       waveAmount = amount;

  final String label;
  final NetworkFundSnapshot? snapshot;
  final int? waveAmount;
  final String asset;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final NetworkFundSnapshot? fund = snapshot;
    final int amount = fund?.available ?? waveAmount ?? 0;
    final String caption = fund == null
        ? 'Encaissé aujourd’hui'
        : 'Engagé ${formatCfa(fund.committed)}';
    final String? movementCaption = fund == null
        ? null
        : '+${formatCfa(fund.totalIncoming)}  ·  -${formatCfa(fund.totalOutgoing)}';

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
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: accent.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontSize: IzyTelTypeScale.micro,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatCfa(amount),
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: IzyTelColors.textPrimary,
                      fontSize: IzyTelTypeScale.label,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (movementCaption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    movementCaption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: IzyTelColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
