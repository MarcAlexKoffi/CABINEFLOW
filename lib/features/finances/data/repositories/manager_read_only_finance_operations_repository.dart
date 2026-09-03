import 'package:cabine_flow/features/finances/data/repositories/supabase_phase5_finance_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_supplier_registry_repository.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/finance_operations_repository.dart';

/// Vue financière Manager strictement en lecture.
///
/// Les flux déjà migrés vers Supabase restent visibles. Les domaines encore
/// protégés par les anciennes rules Firestore (crédits, dépenses, caisse Wave,
/// clôture) ne sont ni lus ni écrits depuis ce dépôt.
class ManagerReadOnlyFinanceOperationsRepository
    implements FinanceOperationsRepository {
  ManagerReadOnlyFinanceOperationsRepository({
    SupabasePhase5FinanceRepository? phase5Repository,
    SupabaseSupplierRegistryRepository? supplierRepository,
  }) : _phase5 = phase5Repository ?? SupabasePhase5FinanceRepository(),
       _suppliers = supplierRepository ?? SupabaseSupplierRegistryRepository();

  final SupabasePhase5FinanceRepository _phase5;
  final SupabaseSupplierRegistryRepository _suppliers;

  @override
  Stream<List<FinanceSupplier>> watchSuppliers() => _suppliers.watchSuppliers();

  @override
  Stream<List<SupplierAccount>> watchSupplierAccounts() =>
      _phase5.watchSupplierAccounts();

  @override
  Stream<List<SupplierRecharge>> watchSupplierRecharges() =>
      _phase5.watchSupplierRecharges();

  @override
  Stream<List<SupplierPayment>> watchSupplierPayments() =>
      _phase5.watchSupplierPayments();

  @override
  Stream<List<CustomerCredit>> watchCustomerCredits() =>
      Stream<List<CustomerCredit>>.value(const <CustomerCredit>[]);

  @override
  Stream<List<CustomerCreditSettlement>> watchCustomerCreditSettlements() =>
      Stream<List<CustomerCreditSettlement>>.value(
        const <CustomerCreditSettlement>[],
      );

  @override
  Stream<List<FinanceExpense>> watchExpenses() =>
      Stream<List<FinanceExpense>>.value(const <FinanceExpense>[]);

  @override
  Stream<WaveOpeningBalance?> watchWaveOpeningBalance() =>
      Stream<WaveOpeningBalance?>.value(null);

  @override
  Stream<List<WaveBalanceAdjustment>> watchWaveBalanceAdjustments() =>
      Stream<List<WaveBalanceAdjustment>>.value(
        const <WaveBalanceAdjustment>[],
      );

  @override
  Stream<List<DailyFinancialClosing>> watchDailyClosings() =>
      Stream<List<DailyFinancialClosing>>.value(
        const <DailyFinancialClosing>[],
      );

  Never _adminOnly() {
    throw StateError(
      'Cette opération financière reste réservée à l’Administrateur.',
    );
  }

  @override
  Future<String> createSupplier({
    required String name,
    required String phoneNumber,
    required String staffId,
    required String staffName,
    String? note,
  }) async => _adminOnly();

  @override
  Future<void> setSupplierActive({
    required String supplierId,
    required bool isActive,
    required String staffId,
    required String staffName,
  }) async => _adminOnly();

  @override
  Future<void> updateSupplier({
    required String supplierId,
    required String name,
    required String phoneNumber,
    required String staffId,
    required String staffName,
    String? note,
  }) async => _adminOnly();

  @override
  Future<void> deleteSupplier({required String supplierId}) async =>
      _adminOnly();

  @override
  Future<String> recordSupplierRecharge({
    required SupplierRechargeDraft draft,
    required String staffId,
    required String staffName,
  }) async => _adminOnly();

  @override
  Future<String> recordSupplierPayment({
    required SupplierPaymentDraft draft,
    required String staffId,
    required String staffName,
  }) async => _adminOnly();

  @override
  Future<String> createCustomerCredit({
    required CustomerCreditDraft draft,
    required String staffId,
    required String staffName,
  }) async => _adminOnly();

  @override
  Future<String> settleCustomerCredit({
    required String creditId,
    required int amount,
    required FinancePaymentChannel channel,
    required String reference,
    required String staffId,
    required String staffName,
    String? note,
  }) async => _adminOnly();

  @override
  Future<String> recordExpense({
    required FinanceExpenseDraft draft,
    required String staffId,
    required String staffName,
  }) async => _adminOnly();

  @override
  Future<void> setWaveOpeningBalance({
    required int amount,
    required String staffId,
    required String staffName,
    String? note,
  }) async => _adminOnly();

  @override
  Future<void> createDailyClosing({
    required DailyFinancialClosingDraft draft,
    required String staffId,
    required String staffName,
  }) async => _adminOnly();
}
