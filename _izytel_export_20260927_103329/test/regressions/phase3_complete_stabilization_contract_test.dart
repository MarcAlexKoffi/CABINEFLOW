import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  group('Phase 3 complete - stabilisation technique', () {
    test('les pollers appliquent un backoff et se remettent apres succes', () {
      final String policy = read('lib/core/resilience/backend_failure_policy.dart');
      final List<String> pollers = <String>[
        'lib/features/agents/data/repositories/supabase_agent_issue_repository.dart',
        'lib/features/finances/data/repositories/supabase_supplier_registry_repository.dart',
        'lib/features/finances/data/repositories/supabase_phase5_finance_repository.dart',
        'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
        'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
      ];

      expect(policy, contains('retryDelay('));
      expect(policy, contains('retryIdempotent<T>'));
      expect(policy, contains('canRetryRead(error)'));
      for (final String path in pollers) {
        final String source = read(path);
        expect(source, contains('consecutiveFailures'));
        expect(source, contains('BackendFailurePolicy.retryDelay('));
      }
    });

    test('Firestore mobile garde un cache persistant sans imposer le cache Web', () {
      final String bootstrap = read('lib/core/firebase/firebase_bootstrap.dart');
      expect(bootstrap, contains('if (kIsWeb) return;'));
      expect(bootstrap, contains('TargetPlatform.android'));
      expect(bootstrap, contains('TargetPlatform.iOS'));
      expect(bootstrap, contains('persistenceEnabled: true'));
    });

    test('le pont de preuve ne masque que les pannes Supabase transitoires', () {
      final String hybrid = read(
        'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
      );
      final int start = hybrid.indexOf('Future<OrderProof?> fetchOrderProof');
      final int end = hybrid.indexOf('Future<OrderProof> saveOrderProof', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final String block = hybrid.substring(start, end);
      expect(block, contains('_proofs.fetchProof'));
      expect(block, contains('BackendFailurePolicy.canRetryRead(error)'));
      expect(block, contains('_firestore.fetchOrderProof'));
      expect(block, contains('Error.throwWithStackTrace'));
    });

    test('le backfill historique est idempotent, tolerant et deterministe', () {
      final String sync = read(
        'lib/features/finances/data/services/phase5_consolidated_synchronizer.dart',
      );
      expect(sync, contains('BackendFailurePolicy.retryIdempotent<void>'));
      expect(sync, contains("_legacyEpochIso = '1970-01-01T00:00:00.000Z'"));
      expect(sync, contains('_historicalInteger('));
      expect(sync, contains("network.startsWith('moov')"));
      expect(sync, contains('DateTime.fromMillisecondsSinceEpoch'));
      expect(sync, isNot(contains('DateTime.now().toUtc().toIso8601String(),')));
    });

    test('les erreurs backend importantes ne restent plus silencieuses', () {
      final List<String> sources = <String>[
        'lib/features/dashboard/presentation/view_models/dashboard_view_model.dart',
        'lib/features/dashboard/presentation/pages/dashboard_page.dart',
        'lib/features/agents/presentation/view_models/agent_activity_view_model.dart',
        'lib/features/agents/presentation/view_models/agent_management_view_model.dart',
        'lib/features/agents/presentation/view_models/agent_detail_view_model.dart',
        'lib/features/orders/presentation/pages/order_detail_page.dart',
        'lib/features/payments/presentation/view_models/payment_request_view_model.dart',
        'lib/features/navigation/presentation/pages/main_shell_page.dart',
      ];
      for (final String path in sources) {
        expect(read(path), contains('IzyTelLog.backendError('), reason: path);
      }
    });

    test('les migrations de securite Supabase sont livrees avec la baseline', () {
      final String security = read(
        'supabase/migrations/20260911_phase3_stabilization_security_hardening.sql',
      );
      final String rls = read(
        'supabase/migrations/20260911_phase3_rls_initplan_optimization.sql',
      );

      expect(security, contains('private.izytel_register_notification_device_internal'));
      expect(security, contains('deny direct notification devices'));
      expect(security, contains('deny direct notification outbox'));
      expect(security, contains('grant select, insert, update on table public.agent_issues'));
      expect(security, contains('grant select, insert, update on table public.phase4_assignment_history'));
      expect(security, contains('grant select on table public.phase5_commissions'));
      expect(rls, contains('(select auth.jwt()'));
      expect(rls, contains('(select private.is_izytel_finance_staff())'));
    });

    test('la Phase 3 ne renomme pas le package ni les roles', () {
      final String app = read('lib/app/app.dart');
      final String phase1 = read('test/regressions/phase1_mobile_finalization_contract_test.dart');
      expect(app, contains('HybridOrdersRepository'));
      expect(app, contains('HybridDashboardRepository'));
      expect(phase1, contains('Admin mobile reste fonctionnel'));
    });

    test('les anomalies de recette terrain restent verrouillees', () {
      final String phase4 = read(
        'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
      );
      final String hybrid = read(
        'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
      );
      final String app = read('lib/app/app.dart');
      final String agentVm = read(
        'lib/features/orders/presentation/view_models/agent_orders_view_model.dart',
      );
      final String migration = read(
        'supabase/migrations/20260911_phase3_refusal_atomic_outcome.sql',
      );

      expect(phase4, contains('Phase4AgentActionOutcome'));
      expect(phase4, contains('outcome.isRefusalApplied'));
      expect(hybrid, contains('refusalOutcome.reassigned'));
      expect(app, contains('_createRecoveryRoute'));
      expect(app, isNot(contains('Impossible d’ouvrir cette page.')));
      expect(agentVm, contains('if (_orders.isEmpty)'));
      expect(migration, contains("'assignment_state', v_row.assignment_state"));
    });

  });
}
