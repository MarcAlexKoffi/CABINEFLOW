import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Manager peut gérer ses fournisseurs et recharger ses Agents par RPC', () {
    final String repository = source(
      'lib/features/finances/data/repositories/manager_read_only_finance_operations_repository.dart',
    );

    expect(repository, contains("'izytel_manager_save_supplier'"));
    expect(repository, contains("'izytel_manager_set_supplier_active'"));
    expect(repository, contains("'izytel_manager_delete_supplier'"));
    expect(repository, contains("'phase5_record_supplier_recharge'"));
    expect(repository, contains('recordSupplierPayment'));
    expect(repository, contains('=> _adminOnly()'));
  });

  test('Interface fournisseur Manager autorise gestion zone mais pas règlement', () {
    final String page = source(
      'lib/features/finances/presentation/pages/supplier_finance_page.dart',
    );

    expect(page, contains('_canManageSuppliers'));
    expect(page, contains('widget.user.isManager'));
    expect(page, contains('_canPaySuppliers'));
    expect(page, contains("'Recharger un Agent'"));
    expect(page, contains('Le règlement financier du fournisseur reste réservé'));
  });

  test('Plus Manager expose fournisseurs de zone', () {
    final String more = source(
      'lib/features/more/presentation/pages/more_page.dart',
    );

    expect(more, contains("title: 'Fournisseurs de ma zone'"));
    expect(more, contains('ManagerReadOnlyFinanceOperationsRepository'));
    expect(more, contains('SupplierFinancePage'));
  });
}
