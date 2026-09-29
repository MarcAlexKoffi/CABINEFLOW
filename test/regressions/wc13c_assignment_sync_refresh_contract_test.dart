import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('manual assignment pull-to-refresh does not restart polling streams', () {
    final String page = read(
      'lib/features/orders/presentation/pages/agent_assignment_page.dart',
    );
    final String vm = read(
      'lib/features/orders/presentation/view_models/agent_assignment_view_model.dart',
    );

    expect(page, contains('onRefresh: _viewModel.refresh'));
    expect(page, isNot(contains('onRefresh: _viewModel.start')));
    expect(vm, contains('Future<void> refresh() async'));
    expect(vm, contains('await _refreshCanonicalOrder();'));
  });

  test('manual assignment fails closed without a canonical order zone', () {
    final String vm = read(
      'lib/features/orders/presentation/view_models/agent_assignment_view_model.dart',
    );
    final String page = read(
      'lib/features/orders/presentation/pages/agent_assignment_page.dart',
    );

    expect(vm, contains('bool get canAssignCanonically'));
    expect(vm, contains('if (!canAssignCanonically)'));
    expect(vm, contains("reason = 'Hors zone de la commande'"));
    expect(
      page,
      contains(
        'Affectation bloquée tant que la zone canonique de la commande n’est pas disponible.',
      ),
    );
  });

  test('WC13C backend sync reads RPC-only context through a guarded definer', () {
    final String sql = read(
      'supabase/migrations/20260929103000_wc13c_fix_order_sync_context_and_capacity_reconcile.sql',
    );

    expect(sql, contains('security definer'));
    expect(sql, contains('from public.customer_order_contexts c'));
    expect(sql, contains("raise exception 'MANAGER_ZONE_REQUIRED'"));
    expect(sql, contains("initialized_from='legacy_firestore'"));
  });
}
