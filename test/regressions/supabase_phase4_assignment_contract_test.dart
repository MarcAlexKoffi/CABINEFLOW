import 'dart:io';

import 'package:cabine_flow/features/orders/data/repositories/supabase_phase4_assignment_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('Phase 4 branche les commandes sur le repository hybride', () {
    final String app = read('lib/app/app.dart');
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final String firestore = read(
      'lib/features/orders/data/repositories/firestore_orders_repository.dart',
    );

    expect(app, contains('HybridOrdersRepository()'));
    expect(app, contains('SupabaseBootstrap.isInitialized'));
    expect(hybrid, contains('FirestoreOrdersRepository('));
    expect(hybrid, contains('enableNativeAutoAssignment: false'));
    expect(firestore, contains('enableNativeAutoAssignment'));
    expect(firestore, contains('if (!_enableNativeAutoAssignment)'));
  });

  test('refus agent est Supabase et ne repasse pas par le refus Firestore', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final int start = hybrid.indexOf(
      'Future<QueueOrder> refuseAgentAssignment',
    );
    final int end = hybrid.indexOf(
      'Future<QueueOrder> startAgentProcessing',
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final String block = hybrid.substring(start, end);

    expect(block, contains('_phase4.refuse('));
    expect(block, contains('cleanedReason.length < 3'));
    expect(block, isNot(contains('_firestore.refuseAgentAssignment(')));
  });

  test('acceptation fait le handoff vers le traitement Firebase valide', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final int start = hybrid.indexOf(
      'Future<QueueOrder> acceptAgentAssignment',
    );
    final int end = hybrid.indexOf(
      'Future<QueueOrder> refuseAgentAssignment',
      start,
    );
    final String block = hybrid.substring(start, end);

    expect(block, contains('_phase4.accept('));
    expect(block, contains('handoffHybridAcceptedAssignment'));
    expect(block, contains('_phase4.markHandoff('));
    expect(block, contains('_phase4.reopenAcceptance('));
  });

  test('affectation automatique conserve critères et round robin 9E', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final String selector = read(
      'lib/features/orders/domain/services/automatic_assignment_selector.dart',
    );

    expect(hybrid, contains('rankEligibleIgnoringPreviousRefusals'));
    expect(hybrid, contains('_withPhase4Usage'));
    expect(hybrid, contains('_phase4.assignRanked('));
    expect(selector, contains('agent.canReceiveIgnoringPreviousRefusals'));
    expect(selector, contains('lastAssignedAt'));
    expect(selector, contains('activeAssignmentCount'));
    expect(selector, contains('todayAssignmentCount'));
    expect(selector, contains('availableCapacityFor'));
  });

  test('les refus historiques Firebase sont importés avant réaffectation', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final String supabase = read(
      'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
    );

    expect(hybrid, contains('autoAssignmentRefusedAgentIds'));
    expect(hybrid, contains('lastAssignmentRefusedAgentId'));
    expect(hybrid, contains('importLegacyRefusals('));
    expect(supabase, contains("'phase4_import_legacy_refusals'"));
  });

  test('les données opérationnelles pré-acceptation viennent de Supabase', () {
    final String supabase = read(
      'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
    );

    for (final String token in <String>[
      'clientWhatsappPhone',
      'beneficiaryPhone',
      'operationType',
      'offerLabel',
      'paymentPayerName',
      'toPendingQueueOrder',
    ]) {
      expect(supabase, contains(token));
    }
  });

  test(
    'traitement reste Firebase mais la preuve passe par Supabase apres handoff',
    () {
      final String hybrid = read(
        'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
      );

      expect(hybrid, contains('_firestore.startAgentProcessing('));
      expect(hybrid, contains('_firestore.resumeAgentProcessing('));

      final int saveProofStart = hybrid.indexOf(
        'Future<OrderProof> saveOrderProof',
      );
      final int successStart = hybrid.indexOf(
        'Future<QueueOrder> markAgentSuccessful',
        saveProofStart,
      );
      final int failedStart = hybrid.indexOf(
        'Future<QueueOrder> markAgentFailed',
        successStart,
      );

      expect(saveProofStart, greaterThanOrEqualTo(0));
      expect(successStart, greaterThan(saveProofStart));
      expect(failedStart, greaterThan(successStart));

      final String saveProofBody = hybrid.substring(
        saveProofStart,
        successStart,
      );
      expect(saveProofBody, contains('_proofs.saveProof('));
      expect(saveProofBody, isNot(contains('_firestore.saveOrderProof(')));

      // Phase 5B1 : les nouvelles preuves restent Supabase-only au dépôt.
      // Le miroir Firestore n'est autorisé que dans la finalisation, tant que
      // la règle legacy exige encore orderProofs/{orderId} pour completed.
      final String successBody = hybrid.substring(successStart, failedStart);
      expect(successBody, contains('_firestore.saveOrderProof('));
      expect(successBody, contains('_firestore.markAgentSuccessful('));

      expect(hybrid, contains('_firestore.markAgentFailed('));
      expect(hybrid, contains('_firestore.putAgentOnHold('));
    },
  );

  test('affectation manuelle reste Supabase-only avant acceptation', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );

    final int start = hybrid.indexOf('Future<QueueOrder> assignToAgent');
    final int end = hybrid.indexOf(
      'Future<Map<String, int>> fetchActiveAssignmentCounts',
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final String block = hybrid.substring(start, end);

    expect(block, contains('_phase4.assignRanked('));
    expect(block, isNot(contains('_firestore.assignToAgent(')));
    expect(block, isNot(contains('_firestore.ensureHybridAssignmentQueue(')));
    expect(
      block,
      isNot(contains('_firestore.releaseHybridStaleAssignmentAsStaff(')),
    );
    expect(block, contains('ignorePreviousRefusals: true'));
  });

  test('les changements Phase 4 reveillent le moteur staff', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final int start = hybrid.indexOf('watchAutomaticAssignmentQueue()');
    final int end = hybrid.indexOf(
      'synchronizeAutomaticAssignmentBacklog()',
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final String block = hybrid.substring(start, end);

    expect(block, contains('_firestore.watchAutomaticAssignmentQueue()'));
    expect(block, contains('_phase4.watchAllForStaff()'));
    expect(block, contains('lastPhase4Signature'));
  });

  test(
    'les acceptations intermediaires sont reconciliees sans double comptage',
    () {
      final String hybrid = read(
        'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
      );
      final String supabase = read(
        'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
      );

      expect(hybrid, contains('reconcileAcceptance('));
      expect(hybrid, contains('Duration(seconds: 15)'));
      expect(supabase, contains("'phase4_reconcile_acceptance'"));
    },
  );

  test('dashboard ne compte pas les affectations Supabase comme sans agent', () {
    final String app = read('lib/app/app.dart');
    final String dashboard = read(
      'lib/features/dashboard/data/repositories/hybrid_dashboard_repository.dart',
    );

    expect(app, contains('HybridDashboardRepository()'));
    expect(dashboard, contains('firebase.statistics.unassignedOrders'));
    expect(dashboard, contains('item.isAssigned'));
    expect(dashboard, contains('firebaseAssignmentSyncedAt == null'));
  });

  test('snapshot Phase 4 construit une commande Agent complète', () {
    final DateTime now = DateTime(2026, 9, 2, 18);
    final Phase4AssignmentSnapshot snapshot = Phase4AssignmentSnapshot(
      orderId: 'order-1',
      orderReference: 'CF-TEST',
      network: MobileNetwork.mtn,
      amount: 1500,
      source: OrderSource.customerWeb,
      clientName: 'Client Test',
      clientWhatsappPhone: '0102030405',
      beneficiaryPhone: '0506070809',
      operationType: OrderOperationType.internetSubscription,
      offerLabel: '1,5 Go',
      paymentStatus: OrderPaymentStatus.confirmed,
      assignmentState: 'assigned',
      firebaseCreatedAt: now,
      updatedAt: now,
      assignedAgentId: 'agent-a',
      assignedAgentName: 'Agent A',
      assignedByUid: 'admin',
      assignmentMode: OrderAssignmentMode.automatic,
      assignedAt: now,
    );

    final QueueOrder order = snapshot.toPendingQueueOrder();
    expect(order.id, 'order-1');
    expect(order.clientName, 'Client Test');
    expect(order.offerLabel, '1,5 Go');
    expect(order.assignmentStatus, OrderAssignmentStatus.assigned);
    expect(order.status, QueueOrderStatus.paidReady);
    expect(order.paymentStatus, OrderPaymentStatus.confirmed);
  });

  test('historique Agent conserve les refus Supabase Phase 4', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final String supabase = read(
      'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
    );
    final String viewModel = read(
      'lib/features/orders/presentation/view_models/agent_orders_view_model.dart',
    );
    final String historyPage = read(
      'lib/features/orders/presentation/pages/agent_history_page.dart',
    );

    expect(hybrid, contains('AgentAssignmentHistoryRepository'));
    expect(hybrid, contains('watchAgentRefusedOrders'));
    expect(supabase, contains(".eq('status', 'refused')"));
    expect(supabase, contains('OrderAssignmentStatus.refused'));
    expect(viewModel, contains('refusedHistoryOrders'));
    expect(viewModel, contains('refusedHistoryCount'));
    expect(historyPage, contains("_tabBox('Refus'"));
    expect(historyPage, contains('Aucun refus enregistré.'));
  });

  test('activité détaillée Agent fusionne les refus Supabase', () {
    final String activity = read(
      'lib/features/agents/data/repositories/firestore_agent_activity_v2_repository.dart',
    );

    expect(activity, contains('watchAgentRefusalHistory(agentId)'));
    expect(activity, contains("status: 'refused'"));
    expect(activity, contains('phase4RefusedAssignments'));
    expect(activity, contains('mergeAssignments()'));
  });

  test(
    'file Admin montre la réaffectation sur la carte sans bannière permanente',
    () {
      final String widgets = read(
        'lib/features/orders/presentation/widgets/orders_widgets.dart',
      );
      final String page = read(
        'lib/features/orders/presentation/pages/orders_page.dart',
      );

      expect(widgets, contains('Réaffectée automatiquement'));
      expect(widgets, contains('après refus'));
      expect(widgets, contains('assignmentLabel'));
      expect(page, isNot(contains('jusqu’à l’acceptation du nouvel agent')));
      expect(page, isNot(contains('commande payée sans agent')));
    },
  );

  test(
    'Plus expose les chemins officiels affectations et commandes échouées',
    () {
      final String more = read(
        'lib/features/more/presentation/pages/more_page.dart',
      );

      expect(more, contains('Affectations & réaffectations'));
      expect(more, contains('Commandes échouées'));
      expect(more, contains('OrdersPage('));
      expect(more, contains('FailedOrdersPage('));
    },
  );
}
