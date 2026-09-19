import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_phase5_finance_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_supplier_registry_repository.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/finance_operations_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Finance opérationnelle Manager bornée à ses zones.
///
/// Le Manager peut gérer ses propres comptes fournisseurs et recharger les
/// Agents de ses zones via des RPC Supabase qui réappliquent le contrôle de
/// périmètre côté serveur. Les règlements fournisseurs et les autres domaines
/// financiers sensibles restent réservés à l’Administrateur.
class ManagerReadOnlyFinanceOperationsRepository
    implements FinanceOperationsRepository {
  ManagerReadOnlyFinanceOperationsRepository({
    SupabasePhase5FinanceRepository? phase5Repository,
    SupabaseSupplierRegistryRepository? supplierRepository,
    SupabaseClient? client,
  }) : _phase5 = phase5Repository ?? SupabasePhase5FinanceRepository(),
       _suppliers = supplierRepository ?? SupabaseSupplierRegistryRepository(),
       _client = client ?? Supabase.instance.client;

  final SupabasePhase5FinanceRepository _phase5;
  final SupabaseSupplierRegistryRepository _suppliers;
  final SupabaseClient _client;

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
  }) async {
    final Object? result = await _client.rpc(
      'izytel_manager_save_supplier',
      params: <String, dynamic>{
        'p_supplier_id': '',
        'p_name': name.trim(),
        'p_phone_number': phoneNumber.trim(),
        'p_note': note,
      },
    );
    return '$result'.trim();
  }

  @override
  Future<void> setSupplierActive({
    required String supplierId,
    required bool isActive,
    required String staffId,
    required String staffName,
  }) async {
    await _client.rpc(
      'izytel_manager_set_supplier_active',
      params: <String, dynamic>{
        'p_supplier_id': supplierId.trim(),
        'p_is_active': isActive,
      },
    );
  }

  @override
  Future<void> updateSupplier({
    required String supplierId,
    required String name,
    required String phoneNumber,
    required String staffId,
    required String staffName,
    String? note,
  }) async {
    await _client.rpc(
      'izytel_manager_save_supplier',
      params: <String, dynamic>{
        'p_supplier_id': supplierId.trim(),
        'p_name': name.trim(),
        'p_phone_number': phoneNumber.trim(),
        'p_note': note,
      },
    );
  }

  @override
  Future<void> deleteSupplier({required String supplierId}) async {
    await _client.rpc(
      'izytel_manager_delete_supplier',
      params: <String, dynamic>{'p_supplier_id': supplierId.trim()},
    );
  }

  @override
  Future<String> recordSupplierRecharge({
    required SupplierRechargeDraft draft,
    required String staffId,
    required String staffName,
  }) async {
    final Object? result = await _client.rpc(
      'phase5_record_supplier_recharge',
      params: <String, dynamic>{
        'p_supplier_id': draft.supplierId,
        'p_agent_id': draft.agentId,
        'p_agent_name': draft.agentName,
        'p_network': draft.network.firestoreValue,
        'p_principal': draft.principalAmount,
        'p_bonus': draft.bonusAmount,
        'p_amount_owed': draft.amountOwed,
        'p_note': draft.note,
        'p_staff_name': staffName.trim(),
        'p_legacy_id': null,
        'p_operation_key': null,
      },
    );
    return '$result'.trim();
  }

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
