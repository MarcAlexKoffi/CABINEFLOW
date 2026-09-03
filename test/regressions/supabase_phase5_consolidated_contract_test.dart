import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('Phase 5 partage le registre financier Supabase entre les rôles', () {
    final String repository = read(
      'lib/features/finances/data/repositories/supabase_phase5_finance_repository.dart',
    );
    for (final String token in <String>[
      'phase5_ensure_capacity_seed',
      'phase5_finalize_order_success',
      'phase5_mark_firestore_success_mirrored',
      'phase5_upsert_order_payment',
      'phase5_record_supplier_recharge',
      'phase5_record_supplier_payment',
      'phase5_mirror_legacy_commission_payout',
      'phase5_import_legacy_batch',
      'phase5_agent_commission_summary',
      "from('phase5_network_movements')",
      "from('phase5_commissions')",
      "from('phase5_supplier_accounts')",
    ]) {
      expect(repository, contains(token));
    }
  });

  test('succès Agent conserve le pont Firebase puis réconcilie Phase 5', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final int start = hybrid.indexOf('Future<QueueOrder> markAgentSuccessful');
    final int end = hybrid.indexOf('Future<QueueOrder> markAgentFailed', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final String block = hybrid.substring(start, end);
    expect(block, contains('fetchAgentCapacitiesForPhase5'));
    expect(block, contains('_phase5Finance.ensureCapacitySeed'));
    expect(block, contains('_firestore.markAgentSuccessful'));
    expect(block, contains('_phase5Finance.finalizeOrderSuccess'));
    expect(block, contains('_phase5Finance.markFirestoreSuccessMirrored'));
    expect(block, contains('_proofs.fetchProof'));
  });

  test('finances fournisseur utilisent Supabase en lecture et miroir', () {
    final String hybrid = read(
      'lib/features/finances/data/repositories/hybrid_finance_operations_repository.dart',
    );
    expect(hybrid, contains('_phase5Finance.watchSupplierAccounts()'));
    expect(hybrid, contains('_phase5Finance.watchSupplierRecharges()'));
    expect(hybrid, contains('_phase5Finance.watchSupplierPayments()'));
    expect(hybrid, contains('_phase5Finance.mirrorSupplierRecharge'));
    expect(hybrid, contains('_phase5Finance.mirrorSupplierPayment'));
    expect(hybrid, contains('_firestore.recordSupplierRecharge'));
    expect(hybrid, contains('_firestore.recordSupplierPayment'));
  });

  test('commissions Agent gardent la page validée et agrégats serveur', () {
    final String app = read('lib/app/app.dart');
    final String hybrid = read(
      'lib/features/commissions/data/repositories/hybrid_commission_repository.dart',
    );
    final String page = read(
      'lib/features/commissions/presentation/pages/agent_commissions_page.dart',
    );
    expect(app, contains('HybridCommissionRepository()'));
    expect(hybrid, contains('AgentCommissionSummaryRepository'));
    expect(hybrid, contains('watchAgentCommissionSummary'));
    expect(page, contains('class AgentCommissionsPage'));
    expect(page, contains('AgentCommissionSummaryRepository'));
    expect(page, contains('summary?.earnedTotal'));
    expect(page, contains('summary?.earnedThisMonth'));
  });

  test('mouvements réseau sont lus via le dépôt hybride', () {
    final String finances = read(
      'lib/features/finances/presentation/pages/finances_page.dart',
    );
    final String network = read(
      'lib/features/finances/data/repositories/hybrid_network_finance_repository.dart',
    );
    expect(finances, contains('HybridNetworkFinanceRepository()'));
    expect(network, contains('_phase5.watchNetworkMovements()'));
    expect(network, isNot(contains('_firestore.watchTransactions()')));
  });

  test('backfill consolidé ne saute pas silencieusement les documents', () {
    final String sync = read(
      'lib/features/finances/data/services/phase5_consolidated_synchronizer.dart',
    );
    expect(sync, contains('if (cursor.backfillComplete) return'));
    expect(sync, contains('throw StateError'));
    expect(sync, contains('_reconcileRecentState'));
    expect(sync, contains('reconcileCapacitySnapshot'));
    expect(sync, contains('importSuccessFinalizations'));
    expect(sync, isNot(contains('.whereType<SupplierRecharge>()')));
  });

  test('le Manager ne reçoit pas les écritures financières Admin par l UI', () {
    final String shell = read(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );
    expect(shell, contains('widget.user.role == UserRole.administrator'));
    expect(shell, isNot(contains('UserRole.supervisor &&')));
  });
}
