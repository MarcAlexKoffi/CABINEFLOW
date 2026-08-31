import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/finances/data/repositories/fake_finance_operations_repository.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFinanceOperationsRepository repository;

  setUp(() {
    repository = FakeFinanceOperationsRepository();
  });

  tearDown(() async {
    await repository.dispose();
  });

  test('recharge puis règlement fournisseur mettent à jour sa dette', () async {
    final String supplierId = await repository.createSupplier(
      name: 'Grossiste Orange',
      phoneNumber: '+2250700000000',
      staffId: 'admin',
      staffName: 'Admin',
    );

    await repository.recordSupplierRecharge(
      draft: SupplierRechargeDraft(
        supplierId: supplierId,
        supplierName: 'Grossiste Orange',
        agentId: 'agent-1',
        agentName: 'Agent 1',
        network: AgentNetwork.orange,
        principalAmount: 100000,
        bonusAmount: 4500,
        amountOwed: 100000,
      ),
      staffId: 'admin',
      staffName: 'Admin',
    );

    SupplierAccount account =
        (await repository.watchSupplierAccounts().first).single;
    expect(account.totalRecharged, 104500);
    expect(account.balance, 100000);

    await repository.recordSupplierPayment(
      draft: SupplierPaymentDraft(
        supplierId: supplierId,
        supplierName: 'Grossiste Orange',
        amount: 25000,
        channel: FinancePaymentChannel.wave,
        reference: 'WAVE-25K',
      ),
      staffId: 'admin',
      staffName: 'Admin',
    );

    account = (await repository.watchSupplierAccounts().first).single;
    expect(account.totalPaid, 25000);
    expect(account.balance, 75000);
  });

  test('empêche le surpaiement fournisseur', () async {
    final DateTime now = DateTime(2026, 8, 30);
    await repository.dispose();
    repository = FakeFinanceOperationsRepository(
      supplierAccounts: <SupplierAccount>[
        SupplierAccount(
          supplierId: 's-1',
          supplierName: 'Fournisseur',
          totalOwed: 10000,
          totalPaid: 9000,
          totalRecharged: 10000,
          rechargeCount: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    await expectLater(
      repository.recordSupplierPayment(
        draft: const SupplierPaymentDraft(
          supplierId: 's-1',
          supplierName: 'Fournisseur',
          amount: 1001,
          channel: FinancePaymentChannel.wave,
          reference: 'OVER',
        ),
        staffId: 'admin',
        staffName: 'Admin',
      ),
      throwsStateError,
    );
  });

  test('un crédit client ne peut être réglé au-delà de son reste dû', () async {
    final String creditId = await repository.createCustomerCredit(
      draft: const CustomerCreditDraft(
        orderId: 'o-1',
        orderReference: 'IZY-1',
        clientName: 'Client',
        clientWhatsappPhone: '+2250700000000',
        amount: 5000,
      ),
      staffId: 'admin',
      staffName: 'Admin',
    );

    await repository.settleCustomerCredit(
      creditId: creditId,
      amount: 3000,
      channel: FinancePaymentChannel.wave,
      reference: 'REG-1',
      staffId: 'admin',
      staffName: 'Admin',
    );

    final CustomerCredit partial =
        (await repository.watchCustomerCredits().first).single;
    expect(partial.status, CustomerCreditStatus.partial);
    expect(partial.outstanding, 2000);

    await expectLater(
      repository.settleCustomerCredit(
        creditId: creditId,
        amount: 2001,
        channel: FinancePaymentChannel.wave,
        reference: 'OVER',
        staffId: 'admin',
        staffName: 'Admin',
      ),
      throwsStateError,
    );

    await repository.settleCustomerCredit(
      creditId: creditId,
      amount: 2000,
      channel: FinancePaymentChannel.cash,
      reference: 'REG-2',
      staffId: 'admin',
      staffName: 'Admin',
    );
    final CustomerCredit settled =
        (await repository.watchCustomerCredits().first).single;
    expect(settled.status, CustomerCreditStatus.settled);
    expect(settled.outstanding, 0);
    expect(settled.settledAt, isNotNull);
  });

  test(
    'chaque recalage Wave conserve un historique immuable en mémoire',
    () async {
      await repository.setWaveOpeningBalance(
        amount: 100000,
        staffId: 'admin',
        staffName: 'Admin',
        note: 'Ouverture',
      );
      await repository.setWaveOpeningBalance(
        amount: 98000,
        staffId: 'admin',
        staffName: 'Admin',
        note: 'Recalage après contrôle',
      );

      final List<WaveBalanceAdjustment> history = await repository
          .watchWaveBalanceAdjustments()
          .first;
      expect(history, hasLength(2));
      expect(history.first.openingBalance, 98000);
      expect(history.first.previousOpeningBalance, 100000);
      expect(history.first.difference, -2000);
    },
  );

  test('interdit une seconde clôture du même jour', () async {
    const DailyFinancialClosingDraft draft = DailyFinancialClosingDraft(
      dateKey: '20260830',
      clientReceipts: 10000,
      successfulOrdersCount: 1,
      successfulOrdersAmount: 10000,
      supplierRechargePrincipal: 0,
      supplierRechargeBonus: 0,
      supplierRechargeReceived: 0,
      supplierPayments: 0,
      creditsCreated: 0,
      creditSettlements: 0,
      customerReceivables: 0,
      expenses: 0,
      refunds: 0,
      commissionsEarned: 10,
      commissionsPaid: 0,
      orangeAvailable: 100000,
      orangeCommitted: 0,
      mtnAvailable: 0,
      mtnCommitted: 0,
      moovAvailable: 0,
      moovCommitted: 0,
      supplierDebt: 0,
      commissionDebt: 10,
      waveTheoreticalBalance: 10000,
      waveActualBalance: 10000,
      estimatedProfit: 0,
    );

    await repository.createDailyClosing(
      draft: draft,
      staffId: 'admin',
      staffName: 'Admin',
    );

    await expectLater(
      repository.createDailyClosing(
        draft: draft,
        staffId: 'admin',
        staffName: 'Admin',
      ),
      throwsStateError,
    );
  });
  test(
    'une recharge fournisseur crée toujours la dette complète du principal',
    () async {
      final String supplierId = await repository.createSupplier(
        name: 'Grossiste MTN',
        phoneNumber: '+2250500000000',
        staffId: 'admin',
        staffName: 'Admin',
      );

      await expectLater(
        repository.recordSupplierRecharge(
          draft: SupplierRechargeDraft(
            supplierId: supplierId,
            supplierName: 'Grossiste MTN',
            agentId: 'agent-1',
            agentName: 'Agent 1',
            network: AgentNetwork.mtn,
            principalAmount: 10000,
            bonusAmount: 400,
            amountOwed: 5000,
          ),
          staffId: 'admin',
          staffName: 'Admin',
        ),
        throwsArgumentError,
      );
    },
  );

  test('une dépense Wave exige une référence traçable', () async {
    await expectLater(
      repository.recordExpense(
        draft: const FinanceExpenseDraft(
          category: FinanceExpenseCategory.internet,
          amount: 1000,
          description: 'Forfait internet',
          channel: FinancePaymentChannel.wave,
        ),
        staffId: 'admin',
        staffName: 'Admin',
      ),
      throwsArgumentError,
    );
  });

  test('un écart Wave de clôture doit être justifié', () async {
    const DailyFinancialClosingDraft draft = DailyFinancialClosingDraft(
      dateKey: '20260829',
      clientReceipts: 0,
      successfulOrdersCount: 0,
      successfulOrdersAmount: 0,
      supplierRechargePrincipal: 0,
      supplierRechargeBonus: 0,
      supplierRechargeReceived: 0,
      supplierPayments: 0,
      creditsCreated: 0,
      creditSettlements: 0,
      customerReceivables: 0,
      expenses: 0,
      refunds: 0,
      commissionsEarned: 0,
      commissionsPaid: 0,
      orangeAvailable: 0,
      orangeCommitted: 0,
      mtnAvailable: 0,
      mtnCommitted: 0,
      moovAvailable: 0,
      moovCommitted: 0,
      supplierDebt: 0,
      commissionDebt: 0,
      waveTheoreticalBalance: 10000,
      waveActualBalance: 9500,
      estimatedProfit: 0,
    );

    await expectLater(
      repository.createDailyClosing(
        draft: draft,
        staffId: 'admin',
        staffName: 'Admin',
      ),
      throwsArgumentError,
    );
  });
}
