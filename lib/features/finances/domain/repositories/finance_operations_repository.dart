import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';

abstract class FinanceOperationsRepository {
  Stream<List<FinanceSupplier>> watchSuppliers();
  Stream<List<SupplierAccount>> watchSupplierAccounts();
  Stream<List<SupplierRecharge>> watchSupplierRecharges();
  Stream<List<SupplierPayment>> watchSupplierPayments();
  Stream<List<CustomerCredit>> watchCustomerCredits();
  Stream<List<CustomerCreditSettlement>> watchCustomerCreditSettlements();
  Stream<List<FinanceExpense>> watchExpenses();
  Stream<WaveOpeningBalance?> watchWaveOpeningBalance();
  Stream<List<WaveBalanceAdjustment>> watchWaveBalanceAdjustments();
  Stream<List<DailyFinancialClosing>> watchDailyClosings();

  Future<String> createSupplier({
    required String name,
    required String phoneNumber,
    required String staffId,
    required String staffName,
    String? note,
  });

  Future<void> setSupplierActive({
    required String supplierId,
    required bool isActive,
    required String staffId,
    required String staffName,
  });

  Future<void> updateSupplier({
    required String supplierId,
    required String name,
    required String phoneNumber,
    required String staffId,
    required String staffName,
    String? note,
  });

  Future<void> deleteSupplier({required String supplierId});

  Future<String> recordSupplierRecharge({
    required SupplierRechargeDraft draft,
    required String staffId,
    required String staffName,
  });

  Future<String> recordSupplierPayment({
    required SupplierPaymentDraft draft,
    required String staffId,
    required String staffName,
  });

  Future<String> createCustomerCredit({
    required CustomerCreditDraft draft,
    required String staffId,
    required String staffName,
  });

  Future<String> settleCustomerCredit({
    required String creditId,
    required int amount,
    required FinancePaymentChannel channel,
    required String reference,
    required String staffId,
    required String staffName,
    String? note,
  });

  Future<String> recordExpense({
    required FinanceExpenseDraft draft,
    required String staffId,
    required String staffName,
  });

  Future<void> setWaveOpeningBalance({
    required int amount,
    required String staffId,
    required String staffName,
    String? note,
  });

  Future<void> createDailyClosing({
    required DailyFinancialClosingDraft draft,
    required String staffId,
    required String staffName,
  });
}
