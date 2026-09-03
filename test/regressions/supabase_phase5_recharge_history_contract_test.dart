import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('Phase 5 garde la pagination serveur des recharges Agent', () {
    final String repository = read(
      'lib/features/finances/data/repositories/supabase_agent_recharge_history_repository.dart',
    );
    expect(repository, contains("'phase5_agent_recharge_page'"));
    expect(repository, contains('pageSize = 50'));
    expect(repository, contains('safePageSize + 1'));
    expect(repository, contains('AgentRechargeHistoryCursor'));
    expect(repository, isNot(contains("collection('supplierRecharges')")));
    expect(repository, isNot(contains('.snapshots()')));
  });

  test('Historique Agent conserve recherche filtres et pagination', () {
    final String page = read(
      'lib/features/orders/presentation/pages/agent_history_page.dart',
    );
    expect(page, contains("_tabBox('Recharges'"));
    expect(page, contains('Rechercher fournisseur, référence ou note'));
    expect(page, contains('AgentNetwork.values'));
    expect(page, contains('showDateRangePicker'));
    expect(page, contains(r"'Page $_rechargePage'"));
    expect(page, contains("label: const Text('Précédent')"));
    expect(page, contains("label: const Text('Suivant')"));
    expect(page, contains('pageSize: 50'));
  });

  test('le backfill Phase 5 est désormais consolidé et idempotent', () {
    final String synchronizer = read(
      'lib/features/finances/data/services/phase5_consolidated_synchronizer.dart',
    );
    expect(synchronizer, contains('defaultBatchSize = 100'));
    expect(synchronizer, contains("collection('supplierRecharges')"));
    expect(synchronizer, contains('importRechargeHistoryBatch'));
    expect(synchronizer, contains('importLegacyBatch'));
    expect(synchronizer, contains('saveSyncCursor'));
    expect(synchronizer, contains('if (cursor.backfillComplete) return'));
    expect(synchronizer, contains('_reconcileRecentState'));
  });

  test('une nouvelle recharge alimente tout le registre financier Phase 5', () {
    final String hybrid = read(
      'lib/features/finances/data/repositories/hybrid_finance_operations_repository.dart',
    );
    final String phase5 = read(
      'lib/features/finances/data/repositories/supabase_phase5_finance_repository.dart',
    );
    expect(hybrid, contains('fetchAgentCapacitiesForPhase5'));
    expect(hybrid, contains('ensureCapacitySeed'));
    expect(hybrid, contains('mirrorSupplierRecharge'));
    expect(hybrid, contains('[Phase5][RechargeMirror]'));
    expect(phase5, contains("'phase5_record_supplier_recharge'"));
    expect(phase5, contains("'phase5_network_movements'"));
  });

  test('seul Admin lance le backfill financier consolidé', () {
    final String shell = read(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );
    expect(shell, contains('Phase5ConsolidatedSynchronizer'));
    expect(shell, contains('_synchronizePhase5ConsolidatedBackfill'));
    expect(shell, contains('widget.user.role == UserRole.administrator'));
    expect(shell, contains('SupabaseBootstrap.isInitialized'));
  });
}
