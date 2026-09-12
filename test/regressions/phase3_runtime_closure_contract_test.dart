import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  group('Phase 3 - correctifs de cloture terrain', () {
    test('un refus ne relit pas une ligne devenue invisible par RLS', () {
      final String phase4 = read(
        'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
      );
      final String migration = read(
        'supabase/migrations/20260911_phase3_refusal_atomic_outcome.sql',
      );

      final int start = phase4.indexOf(
        'Future<Phase4AgentActionOutcome> refuse',
      );
      final int end = phase4.indexOf(
        'Future<Phase4AgentActionOutcome> _agentAction',
        start,
      );
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final String block = phase4.substring(start, end);

      expect(block, isNot(contains('fetchOrder(orderId)')));
      expect(block, contains('outcome.isRefusalApplied'));
      expect(migration, contains('private.phase4_agent_action_internal'));
      expect(migration, contains("'assignment_state'"));
      expect(migration, contains("'reassigned'"));
      expect(migration, contains("'manual_required'"));
      expect(migration, contains('language plpgsql'));
      expect(migration, isNot(contains('security definer')));
    });

    test('une route Android inattendue recupere la session au lieu dune page morte', () {
      final String app = read('lib/app/app.dart');
      expect(app, contains('_createRecoveryRoute'));
      expect(app, contains("IzyTelLog.debug('[Navigation][route-recovery]')"));
      expect(app, contains('SplashPage(authRepository: authRepository)'));
      expect(app, isNot(contains('Impossible d’ouvrir cette page.')));
    });

    test('une erreur temporaire conserve une file Agent deja chargee', () {
      final String viewModel = read(
        'lib/features/orders/presentation/view_models/agent_orders_view_model.dart',
      );
      final String page = read(
        'lib/features/orders/presentation/pages/agent_orders_page.dart',
      );

      expect(viewModel, contains('if (_orders.isEmpty)'));
      expect(viewModel, contains("'AgentOrders.watch-assigned'"));
      expect(viewModel, contains('_errorIsQueueLoad'));
      expect(viewModel, contains('String get errorTitle => _errorIsQueueLoad'));
      expect(viewModel, contains("'Impossible de charger la file'"));
      expect(viewModel, contains("'Action impossible'"));
      expect(page, contains('title: _viewModel.errorTitle'));
      expect(page, contains('attempt == 0 && !_viewModel.isLoading'));
    });

    test('la cloture terrain ne modifie ni design ni roles', () {
      final String app = read('lib/app/app.dart');
      final String phase1 = read(
        'test/regressions/phase1_mobile_finalization_contract_test.dart',
      );
      expect(app, contains('themeMode: ThemeMode.light'));
      expect(app, contains('HybridOrdersRepository()'));
      expect(phase1, contains('Admin mobile reste fonctionnel'));
    });
  });
}
