import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/models/network_finance_models.dart';
import 'package:cabine_flow/features/finances/domain/services/finance_calculators.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  QueueOrder paidOrder({
    required String id,
    required int amount,
    required DateTime paidAt,
  }) {
    return QueueOrder(
      id: id,
      reference: 'IZY-$id',
      clientName: 'Client Test',
      clientWhatsappPhone: '+2250700000000',
      network: MobileNetwork.orange,
      beneficiaryPhone: '+2250700000001',
      operationType: OrderOperationType.unitTransfer,
      offerLabel: 'Transfert',
      amount: amount,
      createdAt: paidAt,
      status: QueueOrderStatus.awaitingCustomerConfirmation,
      paymentStatus: OrderPaymentStatus.confirmed,
      paymentConfirmedAt: paidAt,
    );
  }

  test(
    'caisse Wave ne comptabilise que les flux postérieurs au solde d’ouverture et payés via Wave',
    () {
      final DateTime openingAt = DateTime(2026, 8, 30, 8);
      final DateTime after = DateTime(2026, 8, 30, 10);
      final DateTime before = DateTime(2026, 8, 30, 7);

      final WaveCashSnapshot result = WaveFinanceCalculator.calculate(
        opening: WaveOpeningBalance(
          amount: 100000,
          effectiveAt: openingAt,
          updatedAt: openingAt,
          updatedBy: 'admin',
          updatedByName: 'Admin',
        ),
        orders: <QueueOrder>[
          paidOrder(id: 'after', amount: 20000, paidAt: after),
          paidOrder(id: 'before', amount: 9000, paidAt: before),
        ],
        refunds: const [],
        commissionPayouts: <CommissionPayout>[
          CommissionPayout(
            id: 'cp-1',
            agentId: 'a-1',
            agentName: 'Agent',
            amount: 500,
            paymentChannel: 'wave',
            paymentReference: 'W-COM',
            paidAt: after,
            createdBy: 'admin',
            createdByName: 'Admin',
          ),
        ],
        supplierPayments: <SupplierPayment>[
          SupplierPayment(
            id: 'sp-wave',
            supplierId: 's-1',
            supplierName: 'Fournisseur',
            amount: 5000,
            channel: FinancePaymentChannel.wave,
            reference: 'W-SUP',
            paidAt: after,
            createdBy: 'admin',
            createdByName: 'Admin',
          ),
          SupplierPayment(
            id: 'sp-cash',
            supplierId: 's-1',
            supplierName: 'Fournisseur',
            amount: 8000,
            channel: FinancePaymentChannel.cash,
            reference: 'C-SUP',
            paidAt: after,
            createdBy: 'admin',
            createdByName: 'Admin',
          ),
        ],
        creditSettlements: <CustomerCreditSettlement>[
          CustomerCreditSettlement(
            id: 'cs-wave',
            creditId: 'c-1',
            orderId: 'o-c',
            orderReference: 'IZY-C',
            clientName: 'Client',
            amount: 3000,
            channel: FinancePaymentChannel.wave,
            reference: 'W-CREDIT',
            paidAt: after,
            createdBy: 'admin',
            createdByName: 'Admin',
          ),
          CustomerCreditSettlement(
            id: 'cs-cash',
            creditId: 'c-1',
            orderId: 'o-c',
            orderReference: 'IZY-C',
            clientName: 'Client',
            amount: 1000,
            channel: FinancePaymentChannel.cash,
            reference: 'C-CREDIT',
            paidAt: after,
            createdBy: 'admin',
            createdByName: 'Admin',
          ),
        ],
        expenses: <FinanceExpense>[
          FinanceExpense(
            id: 'e-wave',
            category: FinanceExpenseCategory.internet,
            amount: 2000,
            description: 'Internet',
            channel: FinancePaymentChannel.wave,
            spentAt: after,
            createdBy: 'admin',
            createdByName: 'Admin',
          ),
          FinanceExpense(
            id: 'e-cash',
            category: FinanceExpenseCategory.transport,
            amount: 7000,
            description: 'Transport',
            channel: FinancePaymentChannel.cash,
            spentAt: after,
            createdBy: 'admin',
            createdByName: 'Admin',
          ),
        ],
      );

      expect(result.openingBalance, 100000);
      expect(result.clientPayments, 20000);
      expect(result.creditSettlements, 3000);
      expect(result.supplierPayments, 5000);
      expect(result.expenses, 2000);
      expect(result.commissionPayouts, 500);
      expect(result.theoreticalBalance, 115500);
    },
  );

  test(
    'fonds de roulement tient compte du réseau libre, des créances et des dettes',
    () {
      final DateTime now = DateTime(2026, 8, 30, 12);
      final WorkingCapitalSnapshot result = WorkingCapitalCalculator.calculate(
        waveBalance: 40000,
        networkFunds: <AgentNetwork, NetworkFundSnapshot>{
          AgentNetwork.orange: const NetworkFundSnapshot(
            network: AgentNetwork.orange,
            available: 50000,
            committed: 10000,
            totalIncoming: 0,
            totalOutgoing: 0,
          ),
          AgentNetwork.mtn: const NetworkFundSnapshot(
            network: AgentNetwork.mtn,
            available: 20000,
            committed: 5000,
            totalIncoming: 0,
            totalOutgoing: 0,
          ),
          AgentNetwork.moov: const NetworkFundSnapshot(
            network: AgentNetwork.moov,
            available: 10000,
            committed: 0,
            totalIncoming: 0,
            totalOutgoing: 0,
          ),
        },
        supplierAccounts: <SupplierAccount>[
          SupplierAccount(
            supplierId: 's-1',
            supplierName: 'Fournisseur',
            totalOwed: 30000,
            totalPaid: 10000,
            totalRecharged: 35000,
            rechargeCount: 1,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        credits: <CustomerCredit>[
          CustomerCredit(
            id: 'c-1',
            orderId: 'o-1',
            orderReference: 'IZY-1',
            clientName: 'Client',
            clientWhatsappPhone: '+2250700000000',
            amount: 10000,
            paidAmount: 4000,
            status: CustomerCreditStatus.partial,
            createdAt: now,
            createdBy: 'admin',
            createdByName: 'Admin',
            updatedAt: now,
          ),
        ],
        commissionAccounts: <CommissionAccount>[
          CommissionAccount(
            agentId: 'a-1',
            agentName: 'Agent',
            earnedTotal: 2000,
            paidTotal: 500,
            earnedTransactions: 200,
            updatedAt: now,
          ),
        ],
      );

      expect(result.networkAvailable, 80000);
      expect(result.networkCommitted, 15000);
      expect(result.freeNetworkBalance, 65000);
      expect(result.operatingLiquidity, 105000);
      expect(result.customerReceivables, 6000);
      expect(result.supplierDebt, 20000);
      expect(result.commissionDebt, 1500);
      expect(result.netWorkingCapital, 89500);
    },
  );

  test(
    'clôture estime la marge avec le coût moyen réel des recharges fournisseurs',
    () {
      final DateTime day = DateTime(2026, 8, 30, 18);
      final SupplierRecharge recharge = SupplierRecharge(
        id: 'r-1',
        supplierId: 's-1',
        supplierName: 'Fournisseur',
        agentId: 'a-1',
        agentName: 'Agent',
        network: AgentNetwork.orange,
        principalAmount: 100000,
        bonusAmount: 5000,
        receivedAmount: 105000,
        amountOwed: 100000,
        capacityBefore: 0,
        capacityAfter: 105000,
        createdAt: day,
        createdBy: 'admin',
        createdByName: 'Admin',
      );
      final NetworkTransaction success = NetworkTransaction(
        id: 'order_o-1',
        network: AgentNetwork.orange,
        direction: NetworkTransactionDirection.outgoing,
        type: NetworkTransactionType.orderSuccess,
        amount: 10500,
        capacityBefore: 105000,
        capacityAfter: 94500,
        agentId: 'a-1',
        agentName: 'Agent',
        orderId: 'o-1',
        orderReference: 'IZY-1',
        createdBy: 'a-1',
        createdByRole: 'agent',
        createdAt: day,
      );
      final CommissionEntry commission = CommissionEntry(
        id: 'o-1',
        orderId: 'o-1',
        orderReference: 'IZY-1',
        agentId: 'a-1',
        agentName: 'Agent',
        network: MobileNetwork.orange,
        orderAmount: 10500,
        commissionAmount: 10,
        policyId: CommissionPolicy.current.id,
        policyType: CommissionPolicy.current.type,
        rate: 10,
        earnedAt: day,
      );
      final FinanceExpense expense = FinanceExpense(
        id: 'e-1',
        category: FinanceExpenseCategory.internet,
        amount: 100,
        description: 'Internet',
        channel: FinancePaymentChannel.wave,
        spentAt: day,
        createdBy: 'admin',
        createdByName: 'Admin',
      );

      final DailyClosingComputation result = DailyClosingCalculator.calculate(
        day: day,
        orders: <QueueOrder>[paidOrder(id: 'o-1', amount: 10500, paidAt: day)],
        recharges: <SupplierRecharge>[recharge],
        supplierPayments: const [],
        credits: const [],
        settlements: const [],
        expenses: <FinanceExpense>[expense],
        refunds: const [],
        commissions: <CommissionEntry>[commission],
        commissionPayouts: const [],
        supplierAccounts: <SupplierAccount>[
          SupplierAccount(
            supplierId: 's-1',
            supplierName: 'Fournisseur',
            totalOwed: 100000,
            totalPaid: 0,
            totalRecharged: 105000,
            rechargeCount: 1,
            createdAt: day,
            updatedAt: day,
          ),
        ],
        commissionAccounts: <CommissionAccount>[
          CommissionAccount(
            agentId: 'a-1',
            agentName: 'Agent',
            earnedTotal: 10,
            paidTotal: 0,
            earnedTransactions: 1,
            updatedAt: day,
          ),
        ],
        networkTransactions: <NetworkTransaction>[success],
      );

      // 10 500 de service coûtent 10 000 sur une recharge de 100 000 donnant 105 000.
      // Marge brute 500 - commission 10 - dépense 100 = 390 F.
      expect(result.successfulOrdersAmount, 10500);
      expect(result.estimatedProfit, 390);
      expect(result.supplierDebt, 100000);
      expect(result.commissionDebt, 10);
    },
  );

  test(
    'le coût économique reste basé sur le principal même si le fournisseur est déjà réglé',
    () {
      final DateTime day = DateTime(2026, 8, 30, 20);
      final SupplierRecharge recharge = SupplierRecharge(
        id: 'r-paid',
        supplierId: 's-paid',
        supplierName: 'Fournisseur réglé',
        agentId: 'a-1',
        agentName: 'Agent',
        network: AgentNetwork.orange,
        principalAmount: 100000,
        bonusAmount: 5000,
        receivedAmount: 105000,
        amountOwed: 100000,
        capacityBefore: 0,
        capacityAfter: 105000,
        createdAt: day,
        createdBy: 'admin',
        createdByName: 'Admin',
      );
      final NetworkTransaction success = NetworkTransaction(
        id: 'order_paid_supplier',
        network: AgentNetwork.orange,
        direction: NetworkTransactionDirection.outgoing,
        type: NetworkTransactionType.orderSuccess,
        amount: 10500,
        capacityBefore: 105000,
        capacityAfter: 94500,
        agentId: 'a-1',
        agentName: 'Agent',
        orderId: 'o-paid-supplier',
        orderReference: 'IZY-PAID',
        createdBy: 'a-1',
        createdByRole: 'agent',
        createdAt: day,
      );

      final DailyClosingComputation result = DailyClosingCalculator.calculate(
        day: day,
        orders: <QueueOrder>[
          paidOrder(id: 'o-paid-supplier', amount: 10500, paidAt: day),
        ],
        recharges: <SupplierRecharge>[recharge],
        supplierPayments: const [],
        credits: const [],
        settlements: const [],
        expenses: const [],
        refunds: const [],
        commissions: const [],
        commissionPayouts: const [],
        supplierAccounts: <SupplierAccount>[
          SupplierAccount(
            supplierId: 's-paid',
            supplierName: 'Fournisseur réglé',
            totalOwed: 100000,
            totalPaid: 100000,
            totalRecharged: 105000,
            rechargeCount: 1,
            createdAt: day,
            updatedAt: day,
          ),
        ],
        commissionAccounts: const [],
        networkTransactions: <NetworkTransaction>[success],
      );

      expect(result.estimatedProfit, 500);
      expect(result.supplierDebt, 0);
    },
  );

  test(
    'un remboursement d’une commande jamais exécutée ne crée pas une fausse perte de bénéfice',
    () {
      final DateTime day = DateTime(2026, 8, 30, 21);
      final RefundCase refund = RefundCase(
        id: 'refund-failed',
        orderId: 'failed-order',
        orderReference: 'IZY-FAILED',
        supportRequestId: 'support-1',
        supportRequestType: 'transactionFailed',
        supportRequestDescription: 'Transaction non exécutée',
        customerAuthUid: 'customer-1',
        clientName: 'Client',
        clientWhatsappPhone: '+2250700000000',
        originalAmount: 5000,
        amount: 5000,
        reason: RefundReason.transactionFailed,
        reasonNote: 'Aucun stock consommé',
        paymentChannel: 'wave',
        originalPaymentReference: 'PAY-FAILED',
        status: RefundStatus.refunded,
        requestedAt: day,
        requestedBy: 'admin',
        requestedByName: 'Admin',
        updatedAt: day,
        refundReference: 'REF-FAILED',
        refundedAt: day,
        refundedBy: 'admin',
        refundedByName: 'Admin',
      );

      final DailyClosingComputation result = DailyClosingCalculator.calculate(
        day: day,
        orders: const <QueueOrder>[],
        recharges: const <SupplierRecharge>[],
        supplierPayments: const <SupplierPayment>[],
        credits: const <CustomerCredit>[],
        settlements: const <CustomerCreditSettlement>[],
        expenses: const <FinanceExpense>[],
        refunds: <RefundCase>[refund],
        commissions: const <CommissionEntry>[],
        commissionPayouts: const <CommissionPayout>[],
        supplierAccounts: const <SupplierAccount>[],
        commissionAccounts: const <CommissionAccount>[],
        networkTransactions: const <NetworkTransaction>[],
      );

      expect(result.refunds, 5000);
      expect(result.estimatedProfit, 0);
    },
  );
}
