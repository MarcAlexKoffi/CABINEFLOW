import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('preuve Agent valide et rafraichit le JWT avant Storage Supabase', () {
    final String proof = read(
      'lib/features/orders/data/repositories/supabase_order_proof_repository.dart',
    );
    expect(proof, contains('getIdToken(true)'));
    expect(proof, contains('_assertWritableOrder('));
    expect(proof, contains("'accepted', 'handed_off'"));
    expect(proof, contains("'inProgress', 'onHold'"));
    expect(proof, contains('upsert: previous != null'));
    expect(proof, contains('orphanConflict'));
  });

  test('preuve peut etre ajoutee pendant traitement ou attente', () {
    final String detail = read(
      'lib/features/orders/presentation/pages/agent_order_detail_view.dart',
    );
    expect(detail, contains('QueueOrderStatus.inProgress'));
    expect(detail, contains('QueueOrderStatus.onHold'));
    expect(detail, contains('_compressProofForUpload'));
    expect(detail, isNot(contains('_compressProofForFirestore')));
  });

  test('trigger SQL preuve accepte les commandes en traitement Phase 4', () {
    final String migration = read(
      'supabase/migrations/20260912191500_phase3_order_proof_processing_state_fix.sql',
    );
    expect(migration, contains("v_state not in ('accepted', 'handed_off')"));
    expect(migration, contains("v_order_status not in ('inProgress', 'onHold')"));
    expect(migration, contains("ORDER_NOT_ACCEPTED"));
    expect(migration, contains("ORDER_NOT_IN_PROGRESS"));
    expect(migration, isNot(contains("if v_state <> 'handed_off'")));
  });

  test('historique staff ajoute les commandes Supabase absentes de Firestore', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    expect(hybrid, contains('if (!firebaseById.containsKey(snapshot.orderId))'));
    expect(hybrid, contains('snapshot.toQueueOrder()'));
    expect(hybrid, contains('(!firebaseReady && !phaseReady)'));
    expect(hybrid, contains('Phase3.staff-stream-legacy'));
  });

  test('centre echecs garde Supabase si Firestore legacy refuse la lecture', () {
    final String page = read(
      'lib/features/orders/presentation/pages/failed_orders_page.dart',
    );
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    expect(page, contains('_orderHistoryStream'));
    expect(page, contains('_friendlyHistoryError'));
    expect(page, contains('Les commandes opérationnelles doivent continuer à venir de Supabase.'));
    expect(hybrid, contains('_canIgnoreLegacyStaffReadFailure'));
    expect(hybrid, contains("firebase:permission-denied"));
    expect(hybrid, contains('firebaseOrders = const <QueueOrder>[];'));
    expect(page, isNot(contains('Vérifie que les nouvelles règles ont bien été publiées')));
  });

  test('accueil utilise les donnees operationnelles et capacites Supabase', () {
    final String repository = read(
      'lib/features/dashboard/data/repositories/hybrid_dashboard_repository.dart',
    );
    expect(repository, contains('fetchAllForStaff()'));
    expect(repository, contains('fetchAssignmentCandidates()'));
    expect(repository, contains('availableCapacityFor(network)'));
    expect(repository, contains('todayRevenue: todayRevenue'));
    expect(repository, contains('unassignedOrders: supabaseUnassigned'));
    expect(repository, contains('capacitiesReady: candidatesReady'));
    expect(repository, contains('required bool capacitiesReady,'));
    expect(repository, contains('}) {'));
    expect(repository, contains('ne pas afficher de faux soldes a 0'));
  });

  test('accueil retrouve un bloc bleu contraste sans perdre les actions', () {
    final String page = read(
      'lib/features/dashboard/presentation/pages/dashboard_page.dart',
    );
    final String shell = read(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );
    expect(page, contains('class _OverviewCard'));
    expect(page, contains('LinearGradient'));
    expect(page, contains('Color(0xFF3B63F0)'));
    expect(page, contains('Color(0xFF3157E0)'));
    expect(page, contains("'Encaissements aujourd’hui'"));
    expect(page, contains("label: 'À traiter'"));
    expect(page, contains("label: 'Attente moyenne'"));
    expect(page, contains("title: 'Priorités'"));
    expect(page, contains("title: 'Activité du jour'"));
    expect(page, contains("title: 'Capacités disponibles'"));
    expect(page, contains("title: 'À traiter en priorité'"));
    expect(page, contains('onTap: widget.onOpenPayments'));
    expect(page, contains('onTap: widget.onOpenOrders'));
    expect(page, contains('onTap: _openFailedOrdersCenter'));
    expect(page, contains('onTap: widget.onOpenNetwork'));
    expect(shell, contains('onOpenNetwork: _openNetworkTab'));
  });

  test('menu file Agent donne aux ListTile un vrai Material', () {
    final String page = read(
      'lib/features/orders/presentation/pages/agent_orders_page.dart',
    );
    final int menu = page.indexOf('Future<void> _openQueueModeMenu()');
    final int next = page.indexOf('String _queueHeading', menu);
    final String block = page.substring(menu, next);
    expect(block, contains('child: Material('));
    expect(block, contains('clipBehavior: Clip.antiAlias'));
    expect(block, isNot(contains('decoration: BoxDecoration(')));
  });

  test('erreurs preuve ne retombent plus silencieusement sur le message generique', () {
    final String viewModel = read(
      'lib/features/orders/presentation/view_models/agent_orders_view_model.dart',
    );
    expect(viewModel, contains('error is StorageException'));
    expect(viewModel, contains('error is PostgrestException'));
    expect(viewModel, contains("normalized.contains('socketexception')"));
    expect(viewModel, contains("normalized.contains('jwt')"));
  });
}
