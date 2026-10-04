import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('WC15 centralise le refetch Realtime avec fallback lent', () {
    final String helper = read(
      'lib/core/supabase/supabase_realtime_refetch.dart',
    );

    expect(helper, contains('class SupabaseRealtimeRefetch'));
    expect(helper, contains('fallbackPollInterval'));
    expect(helper, contains('Duration(seconds: 60)'));
    expect(helper, contains('signalCoalesceDelay'));
    expect(helper, contains('realtime.setAuth(token)'));
  });

  test('Finance et fournisseurs ne pollent plus toutes les 3 ou 4 secondes', () {
    final String finance = read(
      'lib/features/finances/data/repositories/'
      'supabase_phase5_finance_repository.dart',
    );
    final String suppliers = read(
      'lib/features/finances/data/repositories/'
      'supabase_supplier_registry_repository.dart',
    );
    final String backoffice = read(
      'lib/backoffice/data/repositories/'
      'supabase_backoffice_finance_repository.dart',
    );

    for (final String source in <String>[finance, suppliers, backoffice]) {
      expect(source, contains('SupabaseRealtimeRefetch.watch'));
      expect(source, contains("table: 'finance_change_feed'"));
      expect(source, isNot(contains('Duration(seconds: 3)')));
      expect(source, isNot(contains('Duration(seconds: 4)')));
    }
  });

  test('Commandes et historique utilisent Realtime au lieu du polling chaud', () {
    final String phase4 = read(
      'lib/features/orders/data/repositories/'
      'supabase_phase4_assignment_repository.dart',
    );
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );

    expect(phase4, contains('SupabaseRealtimeRefetch.watch'));
    expect(
      phase4,
      contains("static const String ordersTable = 'phase4_assignment_orders'"),
    );
    expect(
      phase4,
      contains("static const String historyTable = 'phase4_assignment_history'"),
    );
    expect(phase4, contains('table: ordersTable'));
    expect(phase4, contains('table: historyTable'));
    expect(phase4, isNot(contains('pollInterval = const Duration(seconds: 3)')));

    expect(hybrid, contains('_assignmentCandidateCacheTtl'));
    expect(hybrid, contains('Duration(seconds: 1)'));
    expect(hybrid, contains('_assignmentCandidateFetch'));
    expect(hybrid, contains('_fetchAssignmentCandidatesCached()'));
    expect(hybrid, contains('watchActiveAssignmentCounts()'));
    expect(hybrid, contains('_phase4.watchAllForStaff()'));
  });

  test('Signalements utilisent le signal Realtime et gardent le dernier bon etat', () {
    final String issues = read(
      'lib/features/agents/data/repositories/'
      'supabase_agent_issue_repository.dart',
    );
    final String center = read(
      'lib/features/agents/data/repositories/'
      'supabase_agent_issue_center_repository.dart',
    );

    expect(issues, contains('SupabaseRealtimeRefetch.watch'));
    expect(issues, contains("static const String tableName = 'agent_issues'"));
    expect(issues, contains('table: tableName'));
    expect(issues, isNot(contains('Duration(seconds: 4)')));

    expect(center, contains('SupabaseRealtimeRefetch.watch'));
    expect(center, contains("table: 'agent_issues'"));
    expect(center, isNot(contains('Duration(seconds: 4)')));
  });

  test('Pages Finance et commissions reutilisent leurs streams entre rebuilds', () {
    final String finances = read(
      'lib/features/finances/presentation/pages/finances_page.dart',
    );
    final String supplier = read(
      'lib/features/finances/presentation/pages/supplier_finance_page.dart',
    );
    final String commissions = read(
      'lib/features/commissions/presentation/pages/'
      'commission_management_page.dart',
    );
    final String agentCommissions = read(
      'lib/features/commissions/presentation/pages/agent_commissions_page.dart',
    );

    expect(finances, contains('void initState()'));
    expect(finances, contains('_ordersStream ='));
    expect(finances, contains('_supplierPaymentsStream ='));
    expect(finances, contains('_networkTransactionsStream ='));
    expect(supplier, contains('_suppliersStream ='));
    expect(supplier, contains('_supplierAccountsStream ='));
    expect(commissions, contains('_commissionsStream ='));
    expect(commissions, contains('_payoutsStream ='));
    expect(agentCommissions, contains('_commissionsStream ='));
    expect(agentCommissions, contains('_payoutsStream ='));
    expect(agentCommissions, contains('_summaryStream ='));
  });

  test('Migration WC15 publie historique et ajoute les index chronologiques', () {
    final String migration = read(
      'supabase/migrations/20260929123000_wc15_audit_performance_hardening.sql',
    );

    expect(migration, contains("'phase4_assignment_history'"));
    expect(migration, contains('phase5_commissions_earned_at_idx'));
    expect(migration, contains('phase5_commission_payouts_paid_at_idx'));
    expect(migration, contains('phase5_network_movements_occurred_at_idx'));
    expect(migration, contains('phase5_agent_recharges_occurred_at_idx'));
    expect(migration, contains('phase5_supplier_payments_paid_at_idx'));
    expect(migration, contains('phase4_assignment_orders_updated_at_idx'));
  });
}
