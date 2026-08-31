import 'dart:math' as math;

import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/models/network_finance_models.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';

class WaveCashSnapshot {
  const WaveCashSnapshot({
    required this.openingBalance,
    required this.clientPayments,
    required this.creditSettlements,
    required this.supplierPayments,
    required this.refunds,
    required this.expenses,
    required this.commissionPayouts,
    required this.theoreticalBalance,
    required this.effectiveAt,
    required this.hasOpeningBalance,
  });

  final int openingBalance;
  final int clientPayments;
  final int creditSettlements;
  final int supplierPayments;
  final int refunds;
  final int expenses;
  final int commissionPayouts;
  final int theoreticalBalance;
  final DateTime effectiveAt;
  final bool hasOpeningBalance;

  int get incoming => clientPayments + creditSettlements;
  int get outgoing => supplierPayments + refunds + expenses + commissionPayouts;
}

class WaveFinanceCalculator {
  const WaveFinanceCalculator._();

  static WaveCashSnapshot calculate({
    required WaveOpeningBalance? opening,
    required List<QueueOrder> orders,
    required List<RefundCase> refunds,
    required List<CommissionPayout> commissionPayouts,
    required List<SupplierPayment> supplierPayments,
    required List<CustomerCreditSettlement> creditSettlements,
    required List<FinanceExpense> expenses,
  }) {
    final DateTime effectiveAt = opening?.effectiveAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final int clientPayments = orders.where((QueueOrder order) {
      final DateTime? date = order.paymentConfirmedAt ?? order.paidAt;
      return order.paymentStatus == OrderPaymentStatus.confirmed &&
          date != null &&
          !date.isBefore(effectiveAt);
    }).fold<int>(0, (int total, QueueOrder order) => total + order.amount);

    final int creditIncome = creditSettlements.where((CustomerCreditSettlement value) {
      return value.channel == FinancePaymentChannel.wave &&
          !value.paidAt.isBefore(effectiveAt);
    }).fold<int>(0, (int total, CustomerCreditSettlement value) => total + value.amount);

    final int supplierOut = supplierPayments.where((SupplierPayment value) {
      return value.channel == FinancePaymentChannel.wave &&
          !value.paidAt.isBefore(effectiveAt);
    }).fold<int>(0, (int total, SupplierPayment value) => total + value.amount);

    final int refundOut = refunds.where((RefundCase value) {
      final DateTime? date = value.refundedAt;
      return value.paymentChannel == 'wave' && date != null && !date.isBefore(effectiveAt);
    }).fold<int>(0, (int total, RefundCase value) => total + value.amount);

    final int expenseOut = expenses.where((FinanceExpense value) {
      return value.channel == FinancePaymentChannel.wave &&
          !value.spentAt.isBefore(effectiveAt);
    }).fold<int>(0, (int total, FinanceExpense value) => total + value.amount);

    final int commissionOut = commissionPayouts.where((CommissionPayout value) {
      return value.paymentChannel == 'wave' && !value.paidAt.isBefore(effectiveAt);
    }).fold<int>(0, (int total, CommissionPayout value) => total + value.amount);

    final int initial = opening?.amount ?? 0;
    return WaveCashSnapshot(
      openingBalance: initial,
      clientPayments: clientPayments,
      creditSettlements: creditIncome,
      supplierPayments: supplierOut,
      refunds: refundOut,
      expenses: expenseOut,
      commissionPayouts: commissionOut,
      theoreticalBalance: initial + clientPayments + creditIncome - supplierOut - refundOut - expenseOut - commissionOut,
      effectiveAt: effectiveAt,
      hasOpeningBalance: opening != null,
    );
  }
}

class WorkingCapitalSnapshot {
  const WorkingCapitalSnapshot({
    required this.waveBalance,
    required this.networkAvailable,
    required this.networkCommitted,
    required this.freeNetworkBalance,
    required this.supplierDebt,
    required this.customerReceivables,
    required this.commissionDebt,
    required this.operatingLiquidity,
    required this.netWorkingCapital,
  });

  final int waveBalance;
  final int networkAvailable;
  final int networkCommitted;
  final int freeNetworkBalance;
  final int supplierDebt;
  final int customerReceivables;
  final int commissionDebt;
  final int operatingLiquidity;
  final int netWorkingCapital;
}

class WorkingCapitalCalculator {
  const WorkingCapitalCalculator._();

  static WorkingCapitalSnapshot calculate({
    required int waveBalance,
    required Map<AgentNetwork, NetworkFundSnapshot> networkFunds,
    required List<SupplierAccount> supplierAccounts,
    required List<CustomerCredit> credits,
    required List<CommissionAccount> commissionAccounts,
  }) {
    final int available = networkFunds.values.fold<int>(0, (int total, NetworkFundSnapshot item) => total + item.available);
    final int committed = networkFunds.values.fold<int>(0, (int total, NetworkFundSnapshot item) => total + item.committed);
    final int freeNetwork = networkFunds.values.fold<int>(0, (int total, NetworkFundSnapshot item) {
      return total + math.max(0, item.available - item.committed);
    });
    final int supplierDebt = supplierAccounts.fold<int>(0, (int total, SupplierAccount item) => total + math.max(0, item.balance));
    final int receivables = credits.fold<int>(0, (int total, CustomerCredit item) => total + math.max(0, item.outstanding));
    final int commissionDebt = commissionAccounts.fold<int>(0, (int total, CommissionAccount item) => total + math.max(0, item.balance));
    final int liquidity = waveBalance + freeNetwork;
    return WorkingCapitalSnapshot(
      waveBalance: waveBalance,
      networkAvailable: available,
      networkCommitted: committed,
      freeNetworkBalance: freeNetwork,
      supplierDebt: supplierDebt,
      customerReceivables: receivables,
      commissionDebt: commissionDebt,
      operatingLiquidity: liquidity,
      netWorkingCapital: liquidity + receivables - supplierDebt - commissionDebt,
    );
  }
}

class DailyClosingComputation {
  const DailyClosingComputation({
    required this.clientReceipts,
    required this.successfulOrdersCount,
    required this.successfulOrdersAmount,
    required this.supplierRechargePrincipal,
    required this.supplierRechargeBonus,
    required this.supplierRechargeReceived,
    required this.supplierPayments,
    required this.creditsCreated,
    required this.creditSettlements,
    required this.customerReceivables,
    required this.expenses,
    required this.refunds,
    required this.commissionsEarned,
    required this.commissionsPaid,
    required this.supplierDebt,
    required this.commissionDebt,
    required this.estimatedProfit,
  });

  final int clientReceipts;
  final int successfulOrdersCount;
  final int successfulOrdersAmount;
  final int supplierRechargePrincipal;
  final int supplierRechargeBonus;
  final int supplierRechargeReceived;
  final int supplierPayments;
  final int creditsCreated;
  final int creditSettlements;
  final int customerReceivables;
  final int expenses;
  final int refunds;
  final int commissionsEarned;
  final int commissionsPaid;
  final int supplierDebt;
  final int commissionDebt;
  final int estimatedProfit;
}

class DailyClosingCalculator {
  const DailyClosingCalculator._();

  static bool isSameDay(DateTime value, DateTime day) {
    return value.year == day.year && value.month == day.month && value.day == day.day;
  }

  static DailyClosingComputation calculate({
    required DateTime day,
    required List<QueueOrder> orders,
    required List<SupplierRecharge> recharges,
    required List<SupplierPayment> supplierPayments,
    required List<CustomerCredit> credits,
    required List<CustomerCreditSettlement> settlements,
    required List<FinanceExpense> expenses,
    required List<RefundCase> refunds,
    required List<CommissionEntry> commissions,
    required List<CommissionPayout> commissionPayouts,
    required List<SupplierAccount> supplierAccounts,
    required List<CommissionAccount> commissionAccounts,
    required List<NetworkTransaction> networkTransactions,
  }) {
    final List<QueueOrder> paidToday = orders.where((QueueOrder order) {
      final DateTime? date = order.paymentConfirmedAt ?? order.paidAt;
      return order.paymentStatus == OrderPaymentStatus.confirmed && date != null && isSameDay(date, day);
    }).toList(growable: false);

    final List<NetworkTransaction> successToday = networkTransactions.where((NetworkTransaction item) {
      return item.type == NetworkTransactionType.orderSuccess &&
          item.isOutgoing &&
          isSameDay(item.createdAt, day);
    }).toList(growable: false);

    final List<SupplierRecharge> rechargeToday = recharges.where((SupplierRecharge item) => isSameDay(item.createdAt, day)).toList(growable: false);
    final int supplierPaymentToday = supplierPayments.where((SupplierPayment item) => isSameDay(item.paidAt, day)).fold<int>(0, (int total, SupplierPayment item) => total + item.amount);
    final int creditCreatedToday = credits.where((CustomerCredit item) => isSameDay(item.createdAt, day)).fold<int>(0, (int total, CustomerCredit item) => total + item.amount);
    final int settlementToday = settlements.where((CustomerCreditSettlement item) => isSameDay(item.paidAt, day)).fold<int>(0, (int total, CustomerCreditSettlement item) => total + item.amount);
    final int expenseToday = expenses.where((FinanceExpense item) => isSameDay(item.spentAt, day)).fold<int>(0, (int total, FinanceExpense item) => total + item.amount);
    final List<RefundCase> refundsToday = refunds
        .where((RefundCase item) => item.refundedAt != null && isSameDay(item.refundedAt!, day))
        .toList(growable: false);
    final int refundToday = refundsToday.fold<int>(
      0,
      (int total, RefundCase item) => total + item.amount,
    );
    final Set<String> historicallySuccessfulOrderIds = networkTransactions
        .where(
          (NetworkTransaction item) =>
              item.type == NetworkTransactionType.orderSuccess &&
              item.orderId != null,
        )
        .map((NetworkTransaction item) => item.orderId!)
        .toSet();
    final int profitRefundToday = refundsToday
        .where(
          (RefundCase item) => historicallySuccessfulOrderIds.contains(item.orderId),
        )
        .fold<int>(0, (int total, RefundCase item) => total + item.amount);
    final int commissionEarnedToday = commissions.where((CommissionEntry item) => isSameDay(item.earnedAt, day)).fold<int>(0, (int total, CommissionEntry item) => total + item.commissionAmount);
    final int commissionPaidToday = commissionPayouts.where((CommissionPayout item) => isSameDay(item.paidAt, day)).fold<int>(0, (int total, CommissionPayout item) => total + item.amount);

    final Map<AgentNetwork, int> totalRechargeReceived = <AgentNetwork, int>{
      for (final AgentNetwork network in AgentNetwork.values) network: 0,
    };
    final Map<AgentNetwork, int> totalRechargeCost = <AgentNetwork, int>{
      for (final AgentNetwork network in AgentNetwork.values) network: 0,
    };
    for (final SupplierRecharge recharge in recharges) {
      totalRechargeReceived[recharge.network] = totalRechargeReceived[recharge.network]! + recharge.receivedAmount;
      // Le coût économique du stock est le principal fourni, pas le reste de
      // dette. Un fournisseur déjà réglé a toujours coûté le même principal.
      totalRechargeCost[recharge.network] =
          totalRechargeCost[recharge.network]! + recharge.principalAmount;
    }

    int estimatedNetworkCost = 0;
    for (final NetworkTransaction movement in successToday) {
      final int received = totalRechargeReceived[movement.network]!;
      final int cost = totalRechargeCost[movement.network]!;
      final double ratio = received <= 0 ? 1 : (cost / received).clamp(0, 1).toDouble();
      estimatedNetworkCost += (movement.amount * ratio).round();
    }

    final int successAmount = successToday.fold<int>(0, (int total, NetworkTransaction item) => total + item.amount);
    final int grossMargin = successAmount - estimatedNetworkCost;
    // Un remboursement d'une commande qui n'a jamais consommé de stock ne
    // constitue pas une perte de marge : l'encaissement initial n'est pas
    // compté comme chiffre d'affaires dans ce calcul. En revanche, rembourser
    // une commande réellement exécutée doit bien diminuer le bénéfice.
    final int estimatedProfit =
        grossMargin - commissionEarnedToday - expenseToday - profitRefundToday;

    return DailyClosingComputation(
      clientReceipts: paidToday.fold<int>(0, (int total, QueueOrder item) => total + item.amount),
      successfulOrdersCount: successToday.length,
      successfulOrdersAmount: successAmount,
      supplierRechargePrincipal: rechargeToday.fold<int>(0, (int total, SupplierRecharge item) => total + item.principalAmount),
      supplierRechargeBonus: rechargeToday.fold<int>(0, (int total, SupplierRecharge item) => total + item.bonusAmount),
      supplierRechargeReceived: rechargeToday.fold<int>(0, (int total, SupplierRecharge item) => total + item.receivedAmount),
      supplierPayments: supplierPaymentToday,
      creditsCreated: creditCreatedToday,
      creditSettlements: settlementToday,
      customerReceivables: credits.fold<int>(0, (int total, CustomerCredit item) => total + math.max(0, item.outstanding)),
      expenses: expenseToday,
      refunds: refundToday,
      commissionsEarned: commissionEarnedToday,
      commissionsPaid: commissionPaidToday,
      supplierDebt: supplierAccounts.fold<int>(0, (int total, SupplierAccount item) => total + math.max(0, item.balance)),
      commissionDebt: commissionAccounts.fold<int>(0, (int total, CommissionAccount item) => total + math.max(0, item.balance)),
      estimatedProfit: estimatedProfit,
    );
  }
}
