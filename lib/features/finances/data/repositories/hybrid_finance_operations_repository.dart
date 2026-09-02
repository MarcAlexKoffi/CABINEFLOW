import 'package:cabine_flow/features/finances/data/repositories/firestore_finance_operations_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_supplier_registry_repository.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/finance_operations_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Phase hybride IzyTel : le registre fournisseur vit sur Supabase tandis que
/// les mouvements financiers, capacités et clôtures restent sur Firebase.
///
/// Un miroir Firestore minimal est conservé uniquement pour les anciennes
/// règles des recharges fournisseur. Il n'est plus la source de vérité du
/// nom, téléphone, statut actif/inactif ou suppression du fournisseur.
class HybridFinanceOperationsRepository implements FinanceOperationsRepository {
  HybridFinanceOperationsRepository({
    FirestoreFinanceOperationsRepository? firestoreRepository,
    SupabaseSupplierRegistryRepository? supplierRegistry,
    FirebaseFirestore? firestore,
  }) : _firestore =
           firestoreRepository ??
           FirestoreFinanceOperationsRepository(firestore: firestore),
       _supplierRegistry =
           supplierRegistry ?? SupabaseSupplierRegistryRepository(),
       _firestoreDb = firestore ?? FirebaseFirestore.instance;

  final FirestoreFinanceOperationsRepository _firestore;
  final SupabaseSupplierRegistryRepository _supplierRegistry;
  final FirebaseFirestore _firestoreDb;
  Future<void>? _legacyImportFuture;

  @override
  Stream<List<FinanceSupplier>> watchSuppliers() async* {
    try {
      await (_legacyImportFuture ??= _importLegacySupplierRegistry());
    } catch (error, stackTrace) {
      _legacyImportFuture = null;
      debugPrint('[HybridFinance][SupplierImport] $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    yield* _supplierRegistry.watchSuppliers();
  }

  Future<void> _importLegacySupplierRegistry() async {
    final List<FinanceSupplier> legacy = await _firestore
        .watchSuppliers()
        .first;
    await _supplierRegistry.importLegacySuppliers(legacy);
  }

  @override
  Future<String> createSupplier({
    required String name,
    required String phoneNumber,
    required String staffId,
    required String staffName,
    String? note,
  }) async {
    final String supplierId = _firestoreDb
        .collection('financeSuppliers')
        .doc()
        .id;

    await _supplierRegistry.createSupplier(
      supplierId: supplierId,
      name: name,
      phoneNumber: phoneNumber,
      staffId: staffId,
      staffName: staffName,
      note: note,
    );

    try {
      await _firestore.createSupplierCompatibilityMirror(
        supplierId: supplierId,
        name: name,
        phoneNumber: phoneNumber,
        staffId: staffId,
        staffName: staffName,
        note: note,
      );
    } catch (_) {
      await _supplierRegistry.hideSupplierAfterMirrorFailure(
        supplierId: supplierId,
        staffId: staffId,
        staffName: staffName,
      );
      rethrow;
    }
    return supplierId;
  }

  @override
  Future<void> updateSupplier({
    required String supplierId,
    required String name,
    required String phoneNumber,
    required String staffId,
    required String staffName,
    String? note,
  }) {
    return _supplierRegistry.updateSupplier(
      supplierId: supplierId,
      name: name,
      phoneNumber: phoneNumber,
      staffId: staffId,
      staffName: staffName,
      note: note,
    );
  }

  @override
  Future<void> setSupplierActive({
    required String supplierId,
    required bool isActive,
    required String staffId,
    required String staffName,
  }) {
    return _supplierRegistry.setSupplierActive(
      supplierId: supplierId,
      isActive: isActive,
      staffId: staffId,
      staffName: staffName,
    );
  }

  @override
  Future<void> deleteSupplier({required String supplierId}) async {
    final List<SupplierAccount> accounts = await _firestore
        .watchSupplierAccounts()
        .first;
    if (accounts.any((SupplierAccount item) => item.supplierId == supplierId)) {
      throw StateError(
        'Ce fournisseur possède déjà un historique financier. '
        'Désactive-le plutôt que de le supprimer.',
      );
    }

    final FinanceSupplier? supplier = await _supplierRegistry.getSupplier(
      supplierId,
    );
    if (supplier == null) throw StateError('Fournisseur introuvable.');

    final String uid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (uid.isEmpty) throw StateError('Aucune session Firebase active.');

    final String currentName =
        (FirebaseAuth.instance.currentUser?.displayName ?? '').trim();
    await _supplierRegistry.softDeleteSupplier(
      supplierId: supplierId,
      staffId: uid,
      staffName: currentName.isEmpty ? 'Administration' : currentName,
    );
  }

  @override
  Future<String> recordSupplierRecharge({
    required SupplierRechargeDraft draft,
    required String staffId,
    required String staffName,
  }) async {
    final FinanceSupplier? supplier = await _supplierRegistry.getSupplier(
      draft.supplierId,
    );
    if (supplier == null || !supplier.isActive) {
      throw StateError('Ce fournisseur est indisponible.');
    }

    return _firestore.recordSupplierRecharge(
      draft: draft,
      staffId: staffId,
      staffName: staffName,
    );
  }

  @override
  Stream<List<SupplierAccount>> watchSupplierAccounts() =>
      _firestore.watchSupplierAccounts();

  @override
  Stream<List<SupplierRecharge>> watchSupplierRecharges() =>
      _firestore.watchSupplierRecharges();

  @override
  Stream<List<SupplierPayment>> watchSupplierPayments() =>
      _firestore.watchSupplierPayments();

  @override
  Future<String> recordSupplierPayment({
    required SupplierPaymentDraft draft,
    required String staffId,
    required String staffName,
  }) => _firestore.recordSupplierPayment(
    draft: draft,
    staffId: staffId,
    staffName: staffName,
  );

  @override
  Stream<List<CustomerCredit>> watchCustomerCredits() =>
      _firestore.watchCustomerCredits();

  @override
  Stream<List<CustomerCreditSettlement>> watchCustomerCreditSettlements() =>
      _firestore.watchCustomerCreditSettlements();

  @override
  Stream<List<FinanceExpense>> watchExpenses() => _firestore.watchExpenses();

  @override
  Stream<WaveOpeningBalance?> watchWaveOpeningBalance() =>
      _firestore.watchWaveOpeningBalance();

  @override
  Stream<List<WaveBalanceAdjustment>> watchWaveBalanceAdjustments() =>
      _firestore.watchWaveBalanceAdjustments();

  @override
  Stream<List<DailyFinancialClosing>> watchDailyClosings() =>
      _firestore.watchDailyClosings();

  @override
  Future<String> createCustomerCredit({
    required CustomerCreditDraft draft,
    required String staffId,
    required String staffName,
  }) => _firestore.createCustomerCredit(
    draft: draft,
    staffId: staffId,
    staffName: staffName,
  );

  @override
  Future<String> settleCustomerCredit({
    required String creditId,
    required int amount,
    required FinancePaymentChannel channel,
    required String reference,
    required String staffId,
    required String staffName,
    String? note,
  }) => _firestore.settleCustomerCredit(
    creditId: creditId,
    amount: amount,
    channel: channel,
    reference: reference,
    staffId: staffId,
    staffName: staffName,
    note: note,
  );

  @override
  Future<String> recordExpense({
    required FinanceExpenseDraft draft,
    required String staffId,
    required String staffName,
  }) => _firestore.recordExpense(
    draft: draft,
    staffId: staffId,
    staffName: staffName,
  );

  @override
  Future<void> setWaveOpeningBalance({
    required int amount,
    required String staffId,
    required String staffName,
    String? note,
  }) => _firestore.setWaveOpeningBalance(
    amount: amount,
    staffId: staffId,
    staffName: staffName,
    note: note,
  );

  @override
  Future<void> createDailyClosing({
    required DailyFinancialClosingDraft draft,
    required String staffId,
    required String staffName,
  }) => _firestore.createDailyClosing(
    draft: draft,
    staffId: staffId,
    staffName: staffName,
  );
}
