import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('Agent post paiement ne depend plus du handoff Firestore', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    expect(hybrid, contains('cutover operationnel Supabase'));
    expect(hybrid, isNot(contains('ensureHybridAssignmentQueue(')));
    expect(hybrid, isNot(contains('handoffHybridAcceptedAssignment(')));
    expect(hybrid, isNot(contains('_phase4.markHandoff(')));
    expect(hybrid, isNot(contains('_phase4.reopenAcceptance(')));
  });

  test('affectation traitement et finalisation ont leurs RPC Supabase', () {
    final String phase4 = read(
      'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
    );
    final String phase5 = read(
      'lib/features/finances/data/repositories/supabase_phase5_finance_repository.dart',
    );
    for (final String rpc in <String>[
      'phase3_sync_order',
      'phase3_assignment_candidates',
      'phase3_agent_is_eligible_for_order',
      'phase4_agent_action',
      'phase3_agent_processing_action',
      'phase3_prepare_failed_order_for_reassignment',
    ]) {
      expect(phase4, contains(rpc));
    }
    expect(phase5, contains('phase5_finalize_order_success'));
  });

  test('capacites et disponibilite Agent ont Supabase pour source canonique', () {
    final String agent = read(
      'lib/features/agents/data/repositories/firestore_agent_repository.dart',
    );
    final String operations = read(
      'lib/features/agents/data/repositories/supabase_agent_operations_repository.dart',
    );
    expect(agent, contains('_watchAgentsWithSupabaseOperations'));
    expect(agent, contains('SupabaseAgentOperationsRepository().watchProfile'));
    expect(agent, contains('SupabaseAgentOperationsRepository().updateOwnOperations'));
    expect(agent, contains('SupabaseAgentOperationsRepository().updateAgentAdmin'));
    expect(operations, contains("tableName = 'phase5_agent_capacities'"));
    expect(operations, contains('phase3_update_own_agent_operations'));
    expect(operations, contains('phase3_admin_update_agent_operations'));
  });

  test('client relit le statut operationnel Supabase sans attendre Firestore', () {
    final String customer = read(
      'lib/features/customer_order/data/repositories/firestore_customer_order_repository.dart',
    );
    final String status = read(
      'lib/features/customer_order/data/repositories/supabase_customer_order_status_repository.dart',
    );
    expect(customer, contains('_overlayOperationalStatus'));
    expect(customer, contains('SupabaseCustomerOrderStatusRepository.pollInterval'));
    expect(status, contains('phase3_customer_order_status'));
    expect(status, contains("row['order_status']"));
    expect(status, contains("row['processing_started_at']"));
    expect(status, contains("row['completed_at']"));
  });

  test('Firestore reste seulement pre-sync ou fallback historique dans le flux Agent', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final int acceptStart = hybrid.indexOf('Future<QueueOrder> acceptAgentAssignment');
    final int historyStart = hybrid.indexOf('Future<List<QueueOrder>> fetchOrderHistory', acceptStart);
    final String agentCriticalPath = hybrid.substring(acceptStart, historyStart);
    expect(agentCriticalPath, contains('_phase4.startProcessing'));
    expect(agentCriticalPath, contains('_phase5Finance.finalizeOrderSuccess'));
    expect(agentCriticalPath, isNot(contains('_firestore.startAgentProcessing')));
    expect(agentCriticalPath, isNot(contains('_firestore.markAgentSuccessful')));
    expect(agentCriticalPath, isNot(contains('_firestore.markAgentFailed')));
    expect(agentCriticalPath, isNot(contains('_firestore.putAgentOnHold')));
  });

  test('aucun patch Firestore Rules nest requis par le cutover', () {
    final String notes = read('PHASE3_COMPLETE_NOTES.md');
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final File obsoletePatch = File(
      'tools/phase3_patch_firestore_manual_handoff.ps1',
    );

    expect(notes, isNot(contains('firebase deploy --only firestore:rules')));
    expect(hybrid, isNot(contains('firebase deploy --only firestore:rules')));
    expect(hybrid, isNot(contains('phase3_patch_firestore_manual_handoff.ps1')));

    // Une extraction cumulative peut laisser le fichier historique sur disque.
    // S'il existe encore, il doit etre un tombstone sans effet et non un patch.
    if (obsoletePatch.existsSync()) {
      final String tombstone = obsoletePatch.readAsStringSync();
      expect(tombstone, contains('OBSOLETE'));
      expect(tombstone, contains('performs no action'));
      expect(tombstone, isNot(contains('firebase deploy')));
      expect(tombstone, isNot(contains('firestore.rules')));
      expect(tombstone, isNot(contains('Copy-Item')));
      expect(tombstone, isNot(contains('Set-Content')));
    }
  });

  test('activite Agent et commissions lisent les sources canoniques Supabase', () {
    final String activity = read(
      'lib/features/agents/data/repositories/firestore_agent_activity_v2_repository.dart',
    );
    expect(activity, contains('watchAgentAssignmentState(agentId)'));
    expect(activity, contains('watchAgentAssignmentHistory(agentId)'));
    expect(activity, contains('watchNetworkMovements(agentId: agentId)'));
    expect(activity, contains('watchCommissions(agentId: agentId)'));
    expect(activity, contains('watchCommissionAccounts(agentId: agentId)'));
    expect(activity, contains('watchCommissionPayouts(agentId: agentId)'));
    expect(activity, contains('SupabaseAgentOperationsRepository'));
    expect(activity, contains('Supabase is canonical once the order is synchronized'));
  });

  test('le RPC exact deligibilite est versionne localement', () {
    final String migration = read(
      'supabase/migrations/20260912162341_phase3_assignment_eligibility_rpc.sql',
    );
    expect(migration, contains('phase3_agent_is_eligible_for_order'));
    expect(migration, contains('private.phase3_agent_is_eligible'));
    expect(migration, contains("raise exception 'STAFF_REQUIRED'"));
    final String security = read(
      'supabase/migrations/20260912163619_phase3_assignment_eligibility_rpc_security.sql',
    );
    expect(security, contains('security invoker'));
    expect(security, contains('private.phase3_agent_is_eligible'));
  });


  test('file Agent et detail restent utilisables sans lecture Firestore', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    expect(hybrid, contains('Firestore is legacy enrichment only after the Phase 3 cutover'));
    expect(hybrid, contains('Phase3.order-detail-legacy-enrichment'));
    final int detail = hybrid.indexOf(
      'Future<QueueOrder> fetchOrderById({required String orderId}) async',
    );
    final int staffStream = hybrid.indexOf(
      'Stream<List<QueueOrder>> _combineStaffOrderStream',
      detail,
    );
    final String detailBody = hybrid.substring(detail, staffStream);
    expect(detailBody.indexOf('_phase4.fetchOrder('), lessThan(detailBody.indexOf('_firestore.fetchOrderById(')));
    expect(detailBody, contains('return snapshot.toQueueOrder('));
  });


  test('dashboard bascule les statuts post-sync sur Supabase', () {
    final String dashboard = read(
      'lib/features/dashboard/data/repositories/hybrid_dashboard_repository.dart',
    );
    expect(dashboard, contains('item.orderStatus == QueueOrderStatus.inProgress'));
    expect(dashboard, contains('item.orderStatus == QueueOrderStatus.completed'));
    expect(dashboard, contains('ordersToProcess: supabaseReady'));
    expect(dashboard, contains('unassignedOrders: supabaseUnassigned'));
  });

}
