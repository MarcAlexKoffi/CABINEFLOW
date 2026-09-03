import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('Phase 3 branche le registre fournisseurs sur Supabase', () {
    final String page = read(
      'lib/features/finances/presentation/pages/finances_page.dart',
    );
    final String hybrid = read(
      'lib/features/finances/data/repositories/'
      'hybrid_finance_operations_repository.dart',
    );
    final String supabase = read(
      'lib/features/finances/data/repositories/'
      'supabase_supplier_registry_repository.dart',
    );

    expect(page, contains('SupabaseBootstrap.isInitialized'));
    expect(page, contains('HybridFinanceOperationsRepository()'));
    expect(supabase, contains("tableName = 'finance_suppliers'"));
    expect(supabase, contains(".eq('is_deleted', false)"));
    expect(supabase, contains('Duration(seconds: 4)'));
    expect(hybrid, contains('_supplierRegistry.watchSuppliers()'));
    expect(hybrid, contains('_supplierRegistry.updateSupplier('));
    expect(hybrid, contains('_supplierRegistry.setSupplierActive('));
  });

  test('suppression fournisseur conserve la traçabilité financière', () {
    final String hybrid = read(
      'lib/features/finances/data/repositories/'
      'hybrid_finance_operations_repository.dart',
    );
    final String supabase = read(
      'lib/features/finances/data/repositories/'
      'supabase_supplier_registry_repository.dart',
    );

    expect(hybrid, contains('.watchSupplierAccounts()'));
    expect(hybrid, contains('.first;'));
    expect(hybrid, contains('historique financier'));
    expect(hybrid, contains('softDeleteSupplier('));
    expect(supabase, contains("'is_deleted': true"));
    expect(supabase, contains("'is_active': false"));
  });

  test('recharges et règlements restent Firebase pendant la phase hybride', () {
    final String hybrid = read(
      'lib/features/finances/data/repositories/'
      'hybrid_finance_operations_repository.dart',
    );
    final String firestore = read(
      'lib/features/finances/data/repositories/'
      'firestore_finance_operations_repository.dart',
    );

    expect(hybrid, contains('_firestore.recordSupplierRecharge('));
    expect(hybrid, contains('_firestore.recordSupplierPayment('));
    expect(hybrid, contains('_firestore.watchSupplierRecharges()'));
    expect(hybrid, contains('_firestore.watchSupplierPayments()'));
    expect(firestore, contains('createSupplierCompatibilityMirror'));
    expect(firestore, contains('compatibilitySupplierName'));
  });

  test('le miroir Firebase ne redevient pas la source des modifications', () {
    final String hybrid = read(
      'lib/features/finances/data/repositories/'
      'hybrid_finance_operations_repository.dart',
    );

    final int updateStart = hybrid.indexOf('Future<void> updateSupplier');
    final int toggleStart = hybrid.indexOf('Future<void> setSupplierActive');
    final int deleteStart = hybrid.indexOf('Future<void> deleteSupplier');
    expect(updateStart, greaterThanOrEqualTo(0));
    expect(toggleStart, greaterThan(updateStart));
    expect(deleteStart, greaterThan(toggleStart));

    final String updateBlock = hybrid.substring(updateStart, toggleStart);
    final String toggleBlock = hybrid.substring(toggleStart, deleteStart);
    expect(updateBlock, contains('_supplierRegistry.updateSupplier'));
    expect(updateBlock, isNot(contains('_firestore.updateSupplier')));
    expect(toggleBlock, contains('_supplierRegistry.setSupplierActive'));
    expect(toggleBlock, isNot(contains('_firestore.setSupplierActive')));
  });
}
