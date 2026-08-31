import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
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
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class WorkingCapitalPage extends StatefulWidget {
  const WorkingCapitalPage({
    super.key,
    required this.ordersRepository,
    required this.refundRepository,
    required this.commissionRepository,
    required this.agentRepository,
    required this.networkFinanceRepository,
    required this.financeRepository,
  });

  final OrdersRepository ordersRepository;
  final RefundRepository refundRepository;
  final CommissionRepository commissionRepository;
  final AgentRepository agentRepository;
  final NetworkFinanceRepository networkFinanceRepository;
  final FinanceOperationsRepository financeRepository;

  @override
  State<WorkingCapitalPage> createState() => _WorkingCapitalPageState();
}

class _WorkingCapitalPageState extends State<WorkingCapitalPage> {
  late Future<_WorkingCapitalData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Stream<List<QueueOrder>> get _ordersStream {
    final OrdersRepository repository = widget.ordersRepository;
    if (repository is OrderHistoryRepository) return (repository as OrderHistoryRepository).watchOrderHistory();
    return repository.watchPaymentTrackingOrders();
  }

  Future<_WorkingCapitalData> _load() async {
    final List<QueueOrder> orders = await _ordersStream.first;
    final List<AgentDirectoryEntry> agents = await widget.agentRepository.watchAgents().first;
    final List<NetworkTransaction> networkTransactions = await widget.networkFinanceRepository.watchTransactions().first;
    final List<SupplierAccount> supplierAccounts = await widget.financeRepository.watchSupplierAccounts().first;
    final List<CustomerCredit> credits = await widget.financeRepository.watchCustomerCredits().first;
    final List<CommissionAccount> commissionAccounts = await widget.commissionRepository.watchAccounts().first;
    final WaveOpeningBalance? opening = await widget.financeRepository.watchWaveOpeningBalance().first;
    final List<RefundCase> refunds = await widget.refundRepository.watchAll().first;
    final List<CommissionPayout> payouts = await widget.commissionRepository.watchPayouts().first;
    final List<SupplierPayment> supplierPayments = await widget.financeRepository.watchSupplierPayments().first;
    final List<CustomerCreditSettlement> settlements = await widget.financeRepository.watchCustomerCreditSettlements().first;
    final List<FinanceExpense> expenses = await widget.financeRepository.watchExpenses().first;

    final Map<AgentNetwork, NetworkFundSnapshot> funds = NetworkFinanceCalculator.calculate(
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
    return _WorkingCapitalData(
      funds: funds,
      snapshot: WorkingCapitalCalculator.calculate(
        waveBalance: wave.theoreticalBalance,
        networkFunds: funds,
        supplierAccounts: supplierAccounts,
        credits: credits,
        commissionAccounts: commissionAccounts,
      ),
    );
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
        title: const Text('Fonds de roulement', style: TextStyle(fontSize: IzyTelTypeScale.title3, fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _reload, icon: const Icon(Symbols.refresh_rounded))],
      ),
      body: FutureBuilder<_WorkingCapitalData>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<_WorkingCapitalData> snapshot) {
          if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Impossible de calculer le fonds de roulement : ${snapshot.error}', textAlign: TextAlign.center)));
          final _WorkingCapitalData data = snapshot.data!;
          final WorkingCapitalSnapshot fund = data.snapshot;
          return ListView(padding: const EdgeInsets.all(20), children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: fund.netWorkingCapital >= 0 ? IzyTelColors.primary : IzyTelColors.error, borderRadius: BorderRadius.circular(IzyTelRadii.largeCard)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Fonds de roulement net', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text(formatCfaFull(fund.netWorkingCapital), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                Text('Liquidité opérationnelle ${formatCfa(fund.operatingLiquidity)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: FinancialMetricCard(label: 'Wave théorique', value: formatCfa(fund.waveBalance), icon: Symbols.account_balance_wallet_rounded, accent: IzyTelColors.wave)),
              const SizedBox(width: 10),
              Expanded(child: FinancialMetricCard(label: 'Réseaux libres', value: formatCfa(fund.freeNetworkBalance), icon: Symbols.cell_tower_rounded, accent: IzyTelColors.primary, caption: '${formatCfa(fund.networkCommitted)} engagés')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: FinancialMetricCard(label: 'Créances clients', value: formatCfa(fund.customerReceivables), icon: Symbols.request_quote_rounded, accent: IzyTelColors.success)),
              const SizedBox(width: 10),
              Expanded(child: FinancialMetricCard(label: 'Dettes fournisseurs', value: formatCfa(fund.supplierDebt), icon: Symbols.inventory_2_rounded, accent: IzyTelColors.warning)),
            ]),
            const SizedBox(height: 10),
            FinancialMetricCard(label: 'Commissions dues aux Agents', value: formatCfa(fund.commissionDebt), icon: Symbols.payments_rounded, accent: fund.commissionDebt > 0 ? IzyTelColors.warning : IzyTelColors.success),
            const SizedBox(height: 22),
            const Text('Détail réseaux', style: TextStyle(fontWeight: FontWeight.w800, color: IzyTelColors.textPrimary)),
            const SizedBox(height: 9),
            ...AgentNetwork.values.map((AgentNetwork network) {
              final NetworkFundSnapshot item = data.funds[network]!;
              final int free = (item.available - item.committed).clamp(0, item.available).toInt();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: IzyTelColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: IzyTelColors.outline)),
                child: Row(children: [
                  Expanded(child: Text(network.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                  Text('Libre ${formatCfa(free)}', style: const TextStyle(fontWeight: FontWeight.w800, color: IzyTelColors.primary)),
                  const SizedBox(width: 10),
                  Text('Engagé ${formatCfa(item.committed)}', style: const TextStyle(fontSize: 11, color: IzyTelColors.textMuted)),
                ]),
              );
            }),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: IzyTelColors.surface, borderRadius: BorderRadius.circular(IzyTelRadii.card), border: Border.all(color: IzyTelColors.outline)),
              child: Text('Calcul : Wave + stock réseau libre + créances clients - dettes fournisseurs - commissions dues. Le stock déjà engagé dans une commande payée n’est pas considéré comme libre.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: IzyTelColors.textSecondary, height: 1.4)),
            ),
          ]);
        },
      ),
    );
  }
}

class _WorkingCapitalData {
  const _WorkingCapitalData({required this.funds, required this.snapshot});
  final Map<AgentNetwork, NetworkFundSnapshot> funds;
  final WorkingCapitalSnapshot snapshot;
}
