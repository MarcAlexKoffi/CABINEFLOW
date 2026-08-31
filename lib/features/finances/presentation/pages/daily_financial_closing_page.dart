import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/models/network_finance_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/finance_operations_repository.dart';
import 'package:cabine_flow/features/finances/domain/repositories/network_finance_repository.dart';
import 'package:cabine_flow/features/finances/domain/services/finance_calculators.dart';
import 'package:cabine_flow/features/finances/domain/services/network_finance_calculator.dart';
import 'package:cabine_flow/features/finances/presentation/widgets/financial_ui.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class DailyFinancialClosingPage extends StatefulWidget {
  const DailyFinancialClosingPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    required this.refundRepository,
    required this.commissionRepository,
    required this.agentRepository,
    required this.networkFinanceRepository,
    required this.financeRepository,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final RefundRepository refundRepository;
  final CommissionRepository commissionRepository;
  final AgentRepository agentRepository;
  final NetworkFinanceRepository networkFinanceRepository;
  final FinanceOperationsRepository financeRepository;

  @override
  State<DailyFinancialClosingPage> createState() =>
      _DailyFinancialClosingPageState();
}

class _DailyFinancialClosingPageState extends State<DailyFinancialClosingPage> {
  late Future<DailyFinancialClosingDraft> _previewFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _previewFuture = _loadPreview();
  }

  Stream<List<QueueOrder>> get _ordersStream {
    final OrdersRepository repository = widget.ordersRepository;
    if (repository is OrderHistoryRepository) {
      return (repository as OrderHistoryRepository).watchOrderHistory();
    }
    return repository.watchPaymentTrackingOrders();
  }

  Future<DailyFinancialClosingDraft> _loadPreview() async {
    final DateTime now = DateTime.now();
    final String dateKey =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final List<QueueOrder> orders = await _ordersStream.first;
    final List<AgentDirectoryEntry> agents = await widget.agentRepository
        .watchAgents()
        .first;
    final List<NetworkTransaction> networkTransactions = await widget
        .networkFinanceRepository
        .watchTransactions()
        .first;
    final List<SupplierRecharge> recharges = await widget.financeRepository
        .watchSupplierRecharges()
        .first;
    final List<SupplierPayment> supplierPayments = await widget
        .financeRepository
        .watchSupplierPayments()
        .first;
    final List<CustomerCredit> credits = await widget.financeRepository
        .watchCustomerCredits()
        .first;
    final List<CustomerCreditSettlement> settlements = await widget
        .financeRepository
        .watchCustomerCreditSettlements()
        .first;
    final List<FinanceExpense> expenses = await widget.financeRepository
        .watchExpenses()
        .first;
    final List<RefundCase> refunds = await widget.refundRepository
        .watchAll()
        .first;
    final List<CommissionEntry> commissions = await widget.commissionRepository
        .watchCommissions()
        .first;
    final List<CommissionPayout> payouts = await widget.commissionRepository
        .watchPayouts()
        .first;
    final List<SupplierAccount> supplierAccounts = await widget
        .financeRepository
        .watchSupplierAccounts()
        .first;
    final List<CommissionAccount> commissionAccounts = await widget
        .commissionRepository
        .watchAccounts()
        .first;
    final WaveOpeningBalance? opening = await widget.financeRepository
        .watchWaveOpeningBalance()
        .first;

    final Map<AgentNetwork, NetworkFundSnapshot> funds =
        NetworkFinanceCalculator.calculate(
          agents: agents,
          orders: orders,
          transactions: networkTransactions,
        );
    final WaveCashSnapshot wave = WaveFinanceCalculator.calculate(
      opening: opening,
      orders: orders,
      refunds: refunds,
      commissionPayouts: payouts,
      supplierPayments: supplierPayments,
      creditSettlements: settlements,
      expenses: expenses,
    );
    final DailyClosingComputation closing = DailyClosingCalculator.calculate(
      day: now,
      orders: orders,
      recharges: recharges,
      supplierPayments: supplierPayments,
      credits: credits,
      settlements: settlements,
      expenses: expenses,
      refunds: refunds,
      commissions: commissions,
      commissionPayouts: payouts,
      supplierAccounts: supplierAccounts,
      commissionAccounts: commissionAccounts,
      networkTransactions: networkTransactions,
    );
    final NetworkFundSnapshot orange = funds[AgentNetwork.orange]!;
    final NetworkFundSnapshot mtn = funds[AgentNetwork.mtn]!;
    final NetworkFundSnapshot moov = funds[AgentNetwork.moov]!;
    return DailyFinancialClosingDraft(
      dateKey: dateKey,
      clientReceipts: closing.clientReceipts,
      successfulOrdersCount: closing.successfulOrdersCount,
      successfulOrdersAmount: closing.successfulOrdersAmount,
      supplierRechargePrincipal: closing.supplierRechargePrincipal,
      supplierRechargeBonus: closing.supplierRechargeBonus,
      supplierRechargeReceived: closing.supplierRechargeReceived,
      supplierPayments: closing.supplierPayments,
      creditsCreated: closing.creditsCreated,
      creditSettlements: closing.creditSettlements,
      customerReceivables: closing.customerReceivables,
      expenses: closing.expenses,
      refunds: closing.refunds,
      commissionsEarned: closing.commissionsEarned,
      commissionsPaid: closing.commissionsPaid,
      orangeAvailable: orange.available,
      orangeCommitted: orange.committed,
      mtnAvailable: mtn.available,
      mtnCommitted: mtn.committed,
      moovAvailable: moov.available,
      moovCommitted: moov.committed,
      supplierDebt: closing.supplierDebt,
      commissionDebt: closing.commissionDebt,
      waveTheoreticalBalance: wave.theoreticalBalance,
      waveActualBalance: wave.theoreticalBalance,
      estimatedProfit: closing.estimatedProfit,
    );
  }

  void _reload() {
    setState(() {
      _previewFuture = _loadPreview();
    });
  }

  Future<void> _closeDay(
    DailyFinancialClosingDraft preview,
    List<DailyFinancialClosing> history,
  ) async {
    if (history.any(
      (DailyFinancialClosing item) => item.dateKey == preview.dateKey,
    )) {
      _message('La journée est déjà clôturée.');
      return;
    }
    final TextEditingController actual = TextEditingController(
      text: '${preview.waveTheoreticalBalance.clamp(0, 1000000000)}',
    );
    final TextEditingController differenceNote = TextEditingController();
    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Clôturer la journée'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Wave théorique : ${formatCfaFull(preview.waveTheoreticalBalance)}',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: actual,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Solde Wave réellement constaté',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: differenceNote,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Justification de l’écart (si nécessaire)',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'La clôture sera enregistrée comme un instantané immuable. Tout écart Wave doit être justifié et les corrections ultérieures apparaîtront dans les mouvements du jour suivant.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );
    if (submit != true) return;
    final int actualAmount = int.tryParse(actual.text.trim()) ?? -1;
    if (actualAmount < 0) {
      _message('Le solde Wave réel est invalide.');
      return;
    }
    final int difference = actualAmount - preview.waveTheoreticalBalance;
    final String cleanedDifferenceNote = differenceNote.text.trim();
    if (difference != 0 && cleanedDifferenceNote.length < 3) {
      _message(
        'Justifie l’écart entre le solde Wave réel et le solde théorique.',
      );
      return;
    }
    final DailyFinancialClosingDraft draft = DailyFinancialClosingDraft(
      dateKey: preview.dateKey,
      clientReceipts: preview.clientReceipts,
      successfulOrdersCount: preview.successfulOrdersCount,
      successfulOrdersAmount: preview.successfulOrdersAmount,
      supplierRechargePrincipal: preview.supplierRechargePrincipal,
      supplierRechargeBonus: preview.supplierRechargeBonus,
      supplierRechargeReceived: preview.supplierRechargeReceived,
      supplierPayments: preview.supplierPayments,
      creditsCreated: preview.creditsCreated,
      creditSettlements: preview.creditSettlements,
      customerReceivables: preview.customerReceivables,
      expenses: preview.expenses,
      refunds: preview.refunds,
      commissionsEarned: preview.commissionsEarned,
      commissionsPaid: preview.commissionsPaid,
      orangeAvailable: preview.orangeAvailable,
      orangeCommitted: preview.orangeCommitted,
      mtnAvailable: preview.mtnAvailable,
      mtnCommitted: preview.mtnCommitted,
      moovAvailable: preview.moovAvailable,
      moovCommitted: preview.moovCommitted,
      supplierDebt: preview.supplierDebt,
      commissionDebt: preview.commissionDebt,
      waveTheoreticalBalance: preview.waveTheoreticalBalance,
      waveActualBalance: actualAmount,
      estimatedProfit: preview.estimatedProfit,
      waveDifferenceNote: cleanedDifferenceNote.isEmpty
          ? null
          : cleanedDifferenceNote,
    );
    setState(() => _busy = true);
    try {
      await widget.financeRepository.createDailyClosing(
        draft: draft,
        staffId: widget.user.id,
        staffName: widget.user.name,
      );
      if (mounted) {
        _message('Journée clôturée.');
        _reload();
      }
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) => IzyTelFeedback.show(context, text);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        title: const Text(
          'Clôture journalière',
          style: TextStyle(
            fontSize: IzyTelTypeScale.title3,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _busy ? null : _reload,
            icon: const Icon(Symbols.refresh_rounded),
          ),
        ],
      ),
      body: StreamBuilder<List<DailyFinancialClosing>>(
        stream: widget.financeRepository.watchDailyClosings(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<DailyFinancialClosing>> historySnapshot,
            ) {
              final List<DailyFinancialClosing> history =
                  historySnapshot.data ?? const <DailyFinancialClosing>[];
              return FutureBuilder<DailyFinancialClosingDraft>(
                future: _previewFuture,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<DailyFinancialClosingDraft> previewSnapshot,
                    ) {
                      if (!previewSnapshot.hasData &&
                          previewSnapshot.connectionState ==
                              ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (previewSnapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Impossible de préparer la clôture : ${previewSnapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      final DailyFinancialClosingDraft preview =
                          previewSnapshot.data!;
                      final bool alreadyClosed = history.any(
                        (DailyFinancialClosing item) =>
                            item.dateKey == preview.dateKey,
                      );
                      return ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: FinancialMetricCard(
                                  label: 'Encaissements',
                                  value: formatCfa(preview.clientReceipts),
                                  icon: Symbols.call_received_rounded,
                                  accent: IzyTelColors.success,
                                  caption:
                                      '${preview.successfulOrdersCount} réussite(s)',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FinancialMetricCard(
                                  label: 'Bénéfice estimé',
                                  value: formatCfa(preview.estimatedProfit),
                                  icon: Symbols.trending_up_rounded,
                                  accent: preview.estimatedProfit >= 0
                                      ? IzyTelColors.success
                                      : IzyTelColors.error,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FinancialMetricCard(
                                  label: 'Wave théorique',
                                  value: formatCfa(
                                    preview.waveTheoreticalBalance,
                                  ),
                                  icon: Symbols.account_balance_wallet_rounded,
                                  accent: IzyTelColors.wave,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FinancialMetricCard(
                                  label: 'Créances clients',
                                  value: formatCfa(preview.customerReceivables),
                                  icon: Symbols.request_quote_rounded,
                                  accent: IzyTelColors.warning,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _Section(
                            title: 'Activité du jour',
                            rows: [
                              _Row(
                                'Commandes réussies',
                                preview.successfulOrdersAmount,
                              ),
                              _Row(
                                'Recharges fournisseurs · principal',
                                preview.supplierRechargePrincipal,
                              ),
                              _Row(
                                'Bonus fournisseurs',
                                preview.supplierRechargeBonus,
                              ),
                              _Row(
                                'Stock réseau reçu',
                                preview.supplierRechargeReceived,
                              ),
                              _Row(
                                'Paiements fournisseurs',
                                preview.supplierPayments,
                                outgoing: true,
                              ),
                              _Row('Crédits créés', preview.creditsCreated),
                              _Row(
                                'Crédits encaissés',
                                preview.creditSettlements,
                              ),
                              _Row(
                                'Dépenses',
                                preview.expenses,
                                outgoing: true,
                              ),
                              _Row(
                                'Remboursements',
                                preview.refunds,
                                outgoing: true,
                              ),
                              _Row(
                                'Commissions générées',
                                preview.commissionsEarned,
                                outgoing: true,
                              ),
                              _Row(
                                'Commissions payées',
                                preview.commissionsPaid,
                                outgoing: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _Section(
                            title: 'Position à la clôture',
                            rows: [
                              _Row(
                                'Orange disponible',
                                preview.orangeAvailable,
                              ),
                              _Row('Orange engagé', preview.orangeCommitted),
                              _Row('MTN disponible', preview.mtnAvailable),
                              _Row('MTN engagé', preview.mtnCommitted),
                              _Row('Moov disponible', preview.moovAvailable),
                              _Row('Moov engagé', preview.moovCommitted),
                              _Row(
                                'Dette fournisseurs',
                                preview.supplierDebt,
                                outgoing: true,
                              ),
                              _Row(
                                'Commissions dues',
                                preview.commissionDebt,
                                outgoing: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _busy || alreadyClosed
                                  ? null
                                  : () => _closeDay(preview, history),
                              icon: Icon(
                                alreadyClosed
                                    ? Symbols.check_circle_rounded
                                    : Symbols.lock_rounded,
                              ),
                              label: Text(
                                alreadyClosed
                                    ? 'Journée déjà clôturée'
                                    : 'Clôturer aujourd’hui',
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Historique',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: IzyTelColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 9),
                          if (history.isEmpty)
                            const FinanceEmptyState(
                              icon: Symbols.calendar_month_rounded,
                              title: 'Aucune clôture',
                              message: 'La première clôture apparaîtra ici.',
                            )
                          else
                            ...history
                                .take(30)
                                .map(
                                  (DailyFinancialClosing item) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: IzyTelColors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: IzyTelColors.outline,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Symbols.lock_rounded,
                                          color: IzyTelColors.primary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.dateKey,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                item.waveDifference == 0
                                                    ? 'Wave ${formatCfa(item.waveActualBalance)} · aucun écart'
                                                    : 'Wave ${formatCfa(item.waveActualBalance)} · écart ${formatCfa(item.waveDifference)}${item.waveDifferenceNote?.trim().isNotEmpty == true ? ' · ${item.waveDifferenceNote}' : ''}',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  color: IzyTelColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          formatCfa(item.estimatedProfit),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: item.estimatedProfit >= 0
                                                ? IzyTelColors.success
                                                : IzyTelColors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ],
                      );
                    },
              );
            },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});
  final String title;
  final List<_Row> rows;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(IzyTelRadii.card),
        border: Border.all(color: IzyTelColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: IzyTelColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: IzyTelColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${row.outgoing ? '-' : ''}${formatCfa(row.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: row.outgoing
                          ? IzyTelColors.warning
                          : IzyTelColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row {
  const _Row(this.label, this.amount, {this.outgoing = false});
  final String label;
  final int amount;
  final bool outgoing;
}
