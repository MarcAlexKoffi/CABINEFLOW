import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();
  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  test('M4 Manager lit les finances via des dépôts Supabase dédiés', () {
    final String financeRepo = read(
      'lib/features/finances/data/repositories/manager_read_only_finance_operations_repository.dart',
    );
    final String commissionRepo = read(
      'lib/features/commissions/data/repositories/manager_read_only_commission_repository.dart',
    );

    expect(financeRepo, contains('SupabasePhase5FinanceRepository'));
    expect(financeRepo, contains('SupabaseSupplierRegistryRepository'));
    expect(financeRepo, contains('watchSupplierAccounts'));
    expect(financeRepo, contains('watchSupplierRecharges'));
    expect(financeRepo, contains('watchSupplierPayments'));
    expect(financeRepo, contains('Cette opération financière reste réservée'));
    expect(financeRepo, isNot(contains('FirebaseFirestore')));

    expect(commissionRepo, contains('SupabasePhase5FinanceRepository'));
    expect(commissionRepo, contains('watchCommissionAccounts'));
    expect(commissionRepo, contains('watchCommissionPayouts'));
    expect(commissionRepo, contains('Le versement des commissions reste réservé'));
    expect(commissionRepo, isNot(contains('FirestoreCommissionRepository')));
  });

  test('FinancesPage sépare strictement Manager et Admin', () {
    final String page = compact(
      read('lib/features/finances/presentation/pages/finances_page.dart'),
    );

    expect(page, contains('if (widget.user.isManager) { return _buildManagerOperationalFinance(context); }'));
    expect(page, contains('ManagerReadOnlyFinanceOperationsRepository()'));
    expect(page, contains('ManagerReadOnlyCommissionRepository()'));
    expect(page, contains("title: 'Finances opérationnelles'"));
    expect(page, contains("badge: 'Lecture seule'"));
    expect(page, contains('Caisse Wave, crédits clients, dépenses, clôture'));
    expect(page, contains('FirestoreRefundRepository()'));
  });

  test('écrans Fournisseurs et Commissions neutralisent les écritures Manager', () {
    final String suppliers = compact(
      read('lib/features/finances/presentation/pages/supplier_finance_page.dart'),
    );
    final String performance = compact(
      read('lib/features/commissions/presentation/pages/agent_performance_page.dart'),
    );

    expect(suppliers, contains('widget.user.permissions.canManageFinanceSettings'));
    expect(suppliers, contains("'Lecture seule'"));
    expect(suppliers, contains('if (_canManage)'));
    expect(performance, contains('widget.user.permissions.canManageFinanceSettings'));
  });

  test('Espace Manager expose la supervision financière sans remplacer Agents', () {
    final String more = compact(
      read('lib/features/more/presentation/pages/more_page.dart'),
    );
    final String shell = compact(
      read('lib/features/navigation/presentation/pages/main_shell_page.dart'),
    );

    expect(more, contains("title: 'Finances opérationnelles'"));
    expect(more, contains('permissions.canViewOperationalFinances'));
    expect(more, contains('FinancesPage('));
    expect(shell, contains('widget.user.isManager ? AgentManagementPage('));
    expect(shell, contains('commissionRepository: widget.commissionRepository'));
  });
}
