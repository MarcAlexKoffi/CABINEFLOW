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
    expect(app, contains('HybridOrdersRepository()'));
    expect(app, contains('SupabaseBootstrap.isInitialized'));
    expect(hybrid, contains('FirestoreOrdersRepository('));
    expect(hybrid, contains('enableNativeAutoAssignment: false'));
  });

  test('une commande payee est synchronisee par le RPC Phase 3', () {
    final String supabase = read(
      'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
    );
    expect(supabase, contains("'phase3_sync_order'"));
    expect(supabase, contains("'p_customer_auth_uid'"));
    expect(supabase, contains("'phase3_assignment_candidates'"));
    expect(supabase, contains("'phase3_agent_is_eligible_for_order'"));
  });

  test('acceptation et refus Agent restent atomiques dans Supabase', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final int acceptStart = hybrid.indexOf(
      'Future<QueueOrder> acceptAgentAssignment',
    );
    final int refuseStart = hybrid.indexOf(
      'Future<QueueOrder> refuseAgentAssignment',
      acceptStart,
    );
    final int processingStart = hybrid.indexOf(
      'Future<QueueOrder> startAgentProcessing',
      refuseStart,
    );
    expect(acceptStart, greaterThanOrEqualTo(0));
    expect(refuseStart, greaterThan(acceptStart));
    expect(processingStart, greaterThan(refuseStart));

    final String acceptBlock = hybrid.substring(acceptStart, refuseStart);
    final String refuseBlock = hybrid.substring(refuseStart, processingStart);
    expect(acceptBlock, contains('_phase4.accept('));
    expect(refuseBlock, contains('_phase4.refuse('));
    expect(acceptBlock, isNot(contains('handoffHybridAcceptedAssignment')));
    expect(acceptBlock, isNot(contains('_phase4.markHandoff(')));
    expect(refuseBlock, isNot(contains('_firestore.refuseAgentAssignment(')));
  });

  test('affectation et eligibilite utilisent les capacites Supabase', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final String supabase = read(
      'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
    );
    expect(hybrid, contains('_phase4.fetchAssignmentCandidates()'));
    expect(hybrid, contains('rankEligibleIgnoringPreviousRefusals'));
    expect(hybrid, contains('_phase4.assignRanked('));
    expect(supabase, contains('activeAssignmentCount'));
    expect(supabase, contains('orangeReservedAmount'));
    expect(supabase, contains('todayAssignmentCount'));
  });

  test('affectation manuelle necrit aucun miroir Firestore', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final int start = hybrid.indexOf('Future<QueueOrder> assignToAgent');
    final int end = hybrid.indexOf(
      'Future<Map<String, int>> fetchActiveAssignmentCounts',
      start,
    );
    final String block = hybrid.substring(start, end);
    expect(block, contains('_phase4.assignRanked('));
    expect(block, contains('manualPlanCandidates'));
    expect(block, contains('mode: OrderAssignmentMode.manual'));
    expect(block, isNot(contains('_firestore.assignToAgent(')));
    expect(block, isNot(contains('ensureHybridAssignmentQueue')));
    expect(block, isNot(contains('markFirebaseAssignmentSynced')));
  });

  test('traitement Agent post acceptation est Supabase-only', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final String supabase = read(
      'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
    );
    expect(hybrid, contains('_phase4.startProcessing('));
    expect(hybrid, contains('_phase4.resumeProcessing('));
    expect(hybrid, contains('_phase4.holdProcessing('));
    expect(hybrid, contains('_phase4.failProcessing('));
    expect(hybrid, isNot(contains('_firestore.startAgentProcessing(')));
    expect(hybrid, isNot(contains('_firestore.resumeAgentProcessing(')));
    expect(hybrid, isNot(contains('_firestore.markAgentFailed(')));
    expect(hybrid, isNot(contains('_firestore.putAgentOnHold(')));
    expect(supabase, contains("'phase3_agent_processing_action'"));
  });

  test('succes Agent finalise directement capacite et commission Supabase', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final int start = hybrid.indexOf('Future<QueueOrder> markAgentSuccessful');
    final int end = hybrid.indexOf('Future<QueueOrder> markAgentFailed', start);
    final String block = hybrid.substring(start, end);
    expect(block, contains('_proofs.fetchProof'));
    expect(block, contains('_phase5Finance.finalizeOrderSuccess'));
    expect(block, contains('QueueOrderStatus.completed'));
    expect(block, isNot(contains('_firestore.markAgentSuccessful')));
    expect(block, isNot(contains('_firestore.saveOrderProof')));
    expect(block, isNot(contains('markFirestoreSuccessMirrored')));
  });

  test('le fallback preuve Firestore est uniquement legacy', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final int start = hybrid.indexOf('Future<OrderProof?> fetchOrderProof');
    final int end = hybrid.indexOf('Future<OrderProof> saveOrderProof', start);
    final String block = hybrid.substring(start, end);
    expect(block, contains('_proofs.fetchProof'));
    expect(block, contains('legacyStateUnresolved'));
    expect(block, contains('_firestore.fetchOrderProof'));
  });

  test('les pollers Phase 4 conservent la derniere valeur en panne transitoire', () {
    final String supabase = read(
      'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
    );
    expect(supabase, contains('BackendFailurePolicy.canRetryRead'));
    expect(supabase, contains('BackendFailurePolicy.retryDelay'));
    expect(
      supabase,
      contains('yield lastSuccessful ?? const <Phase4AssignmentSnapshot>[];'),
    );
  });

  test('snapshot Phase 4 construit une commande Agent complete', () {
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
      assignmentState: 'accepted',
      firebaseCreatedAt: now,
      updatedAt: now,
      assignedAgentId: 'agent-a',
      assignedAgentName: 'Agent A',
      assignedByUid: 'admin',
      assignmentMode: OrderAssignmentMode.automatic,
      assignedAt: now,
      orderStatus: QueueOrderStatus.inProgress,
      processingStartedAt: now,
    );

    final QueueOrder order = snapshot.toQueueOrder();
    expect(order.id, 'order-1');
    expect(order.clientName, 'Client Test');
    expect(order.assignmentStatus, OrderAssignmentStatus.accepted);
    expect(order.status, QueueOrderStatus.inProgress);
    expect(order.takenAt, now);
  });

  test('historique Agent conserve les refus Supabase Phase 4', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final String supabase = read(
      'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
    );
    final String historyPage = read(
      'lib/features/orders/presentation/pages/agent_history_page.dart',
    );
    expect(hybrid, contains('watchAgentRefusedOrders'));
    expect(supabase, contains(".eq('status', 'refused')"));
    expect(historyPage, contains("_tabBox('Refus'"));
  });

  test('la file staff est reveillee par Firestore pre-sync et Supabase canonique', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final int start = hybrid.indexOf('watchAutomaticAssignmentQueue()');
    final int end = hybrid.indexOf(
      'synchronizeAutomaticAssignmentBacklog()',
      start,
    );
    final String block = hybrid.substring(start, end);
    expect(block, contains('_firestore.watchAutomaticAssignmentQueue()'));
    expect(block, contains('_phase4.watchAllForStaff()'));
    expect(block, contains('lastPhase4Signature'));
  });
}
