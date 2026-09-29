import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('WC14 server assignment is authoritative round-robin per zone', () {
    final String sql = _read(
      'supabase/migrations/20260929114500_wc14_server_round_robin_assignment.sql',
    );

    expect(sql, contains('pg_advisory_xact_lock'));
    expect(sql, contains('izytel:auto-assignment:'));
    expect(sql, contains('max(h.assigned_at) as last_assigned_at'));
    expect(sql, contains("p_mode='automatic'"));
    expect(sql, contains('usage.last_assigned_at end asc nulls first'));
    expect(sql, contains('private.phase3_agent_is_eligible'));
  });

  test('Agent pull-to-refresh no longer restarts live subscriptions', () {
    final String viewModel = _read(
      'lib/features/orders/presentation/view_models/agent_orders_view_model.dart',
    );
    final String agentOrders = _read(
      'lib/features/orders/presentation/pages/agent_orders_page.dart',
    );
    final String agentHistory = _read(
      'lib/features/orders/presentation/pages/agent_history_page.dart',
    );

    expect(viewModel, contains('Future<void> refresh()'));
    expect(viewModel, contains('.fetchAssignedOrders(agentId: agentId)'));
    expect(viewModel, contains('.fetchAgentRefusedOrders(agentId: agentId)'));
    expect(agentOrders, contains('onRefresh: _viewModel.refresh'));
    expect(agentHistory, contains(': _viewModel.refresh,'));
    expect(agentOrders, isNot(contains('onRefresh: _viewModel.start')));
    expect(agentHistory, isNot(contains(': _viewModel.start,')));
  });

  test('mobile refresh indicator is bounded globally', () {
    final String ui = _read(
      'lib/shared/widgets/izytel/izytel_ui.dart',
    );
    expect(ui, contains('class IzyTelRefreshIndicator'));
    expect(ui, contains('visualTimeout = const Duration(seconds: 5)'));
    expect(ui, contains('raw.timeout(widget.visualTimeout)'));

    const List<String> mobilePages = <String>[
      'lib/features/orders/presentation/pages/agent_history_page.dart',
      'lib/features/orders/presentation/pages/order_history_page.dart',
      'lib/features/orders/presentation/pages/order_detail_page.dart',
      'lib/features/orders/presentation/pages/agent_assignment_page.dart',
      'lib/features/orders/presentation/pages/orders_page.dart',
      'lib/features/orders/presentation/pages/agent_orders_page.dart',
      'lib/features/dashboard/presentation/pages/dashboard_page.dart',
      'lib/features/offers/presentation/pages/offer_management_page.dart',
      'lib/features/support/presentation/pages/support_request_center_page.dart',
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
      'lib/features/control/presentation/pages/manager_pilotage_page.dart',
      'lib/features/payments/presentation/pages/payments_page.dart',
      'lib/features/managers/presentation/pages/manager_accounts_page.dart',
      'lib/features/agents/presentation/pages/agent_activity_page.dart',
      'lib/features/agents/presentation/pages/agent_management_page.dart',
      'lib/features/agents/presentation/pages/agent_home_page.dart',
      'lib/features/agents/presentation/pages/agent_issue_center_page.dart',
      'lib/features/more/presentation/pages/admin_activity_journal_page.dart',
      'lib/features/finances/presentation/pages/financial_reconciliation_page.dart',
      'lib/features/finances/presentation/pages/cabiniste_finance_supervision_page.dart',
      'lib/features/finances/presentation/pages/finances_page.dart',
      'lib/features/team/presentation/pages/team_member_detail_page.dart',
      'lib/features/team/presentation/pages/team_performance_page.dart',
      'lib/features/messaging/presentation/pages/staff_customer_messaging_page.dart',
    ];

    for (final String path in mobilePages) {
      final String source = _read(path);
      expect(source, contains('IzyTelRefreshIndicator('), reason: path);
      final String withoutIzyTel = source.replaceAll(
        'IzyTelRefreshIndicator(',
        '',
      );
      expect(
        withoutIzyTel,
        isNot(contains('RefreshIndicator(')),
        reason: 'Raw unbounded RefreshIndicator remains in $path',
      );
    }
  });

  test('offer refresh is snapshot-based and does not restart realtime', () {
    final String viewModel = _read(
      'lib/features/offers/presentation/view_models/offer_management_view_model.dart',
    );
    final String page = _read(
      'lib/features/offers/presentation/pages/offer_management_page.dart',
    );
    final String contract = _read(
      'lib/features/offers/domain/repositories/admin_offer_repository.dart',
    );

    expect(contract, contains('Future<List<AdminOffer>> fetchOffers();'));
    expect(viewModel, contains('Future<void> refresh()'));
    expect(viewModel, contains('.fetchOffers()'));
    expect(page, contains('onRefresh: _viewModel.refresh'));
    expect(page, isNot(contains('_viewModel.start()')));
  });
}
