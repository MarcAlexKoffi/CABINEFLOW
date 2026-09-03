import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('Phase 5 utilise une pagination serveur pour les recharges Agent', () {
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

  test('Historique Agent expose Recharges avec recherche filtres et pages', () {
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

  test('Backfill Phase 5 progresse par lots avec curseur persistant', () {
    final String synchronizer = read(
      'lib/features/finances/data/services/phase5_recharge_history_synchronizer.dart',
    );
    expect(synchronizer, contains('defaultBatchSize = 100'));
    expect(synchronizer, contains("collection('supplierRecharges')"));
    expect(synchronizer, contains("orderBy('createdAt')"));
    expect(synchronizer, contains('orderBy(FieldPath.documentId)'));
    expect(synchronizer, contains('startAfter'));
    expect(synchronizer, contains('saveSyncCursor'));
    expect(synchronizer, contains('upsertSupplierRecharges'));
  });

  test('Nouvelle recharge financière alimente immédiatement Phase 5', () {
    final String hybrid = read(
      'lib/features/finances/data/repositories/hybrid_finance_operations_repository.dart',
    );
    final String firestore = read(
      'lib/features/finances/data/repositories/firestore_finance_operations_repository.dart',
    );
    expect(hybrid, contains('fetchSupplierRechargeById'));
    expect(hybrid, contains('upsertSupplierRecharges'));
    expect(hybrid, contains('[Phase5][RechargeMirror]'));
    expect(
      firestore,
      contains('Future<SupplierRecharge?> fetchSupplierRechargeById'),
    );
  });

  test('Admin lance la reprise progressive sans bloquer son interface', () {
    final String shell = read(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );
    expect(shell, contains('Phase5RechargeHistorySynchronizer'));
    expect(shell, contains('unawaited(_synchronizePhase5RechargeHistory())'));
    expect(shell, contains('SupabaseBootstrap.isInitialized'));
  });
}
