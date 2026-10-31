import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('order navigation preserves the exact previous route', () {
    final String adminOrders = File(
      'lib/features/orders/presentation/pages/orders_page.dart',
    ).readAsStringSync();
    final String staffNavigation = File(
      'lib/features/orders/presentation/navigation/staff_order_navigation.dart',
    ).readAsStringSync();
    final String agentOrders = File(
      'lib/features/orders/presentation/pages/agent_orders_page.dart',
    ).readAsStringSync();
    final String agentHistory = File(
      'lib/features/orders/presentation/pages/agent_history_page.dart',
    ).readAsStringSync();

    expect(adminOrders, contains('StaffOrderNavigation.openHistory'));
    expect(adminOrders, contains('StaffOrderNavigation.openOrderDetail'));
    expect(adminOrders, isNot(contains('bool _showHistory')));
    expect(adminOrders, isNot(contains('_detailOrder')));

    expect(staffNavigation, contains('context: detailContext'));
    expect(staffNavigation, contains('context: historyContext'));
    expect(staffNavigation, contains('staff-customer-order-history'));

    expect(agentOrders, contains('AgentOrderDetailRoutePage'));
    expect(agentHistory, contains('AgentOrderDetailRoutePage'));
    expect(agentOrders, isNot(contains('_openedOrderId')));
    expect(agentHistory, isNot(contains('_openedOrderId')));
  });

  test('les recherches ne recréent pas leur stream à chaque caractère', () {
    final String journal = File(
      'lib/features/more/presentation/pages/admin_activity_journal_page.dart',
    ).readAsStringSync();
    final String support = File(
      'lib/features/support/presentation/pages/support_request_center_page.dart',
    ).readAsStringSync();
    final String issues = File(
      'lib/features/agents/presentation/pages/agent_issue_center_page.dart',
    ).readAsStringSync();
    final String refunds = File(
      'lib/features/refunds/presentation/pages/refund_management_page.dart',
    ).readAsStringSync();

    expect(
      journal,
      contains('late final Stream<List<QueueOrder>> _ordersStream'),
    );
    expect(journal, contains('stream: _ordersStream'));
    expect(journal, contains('stream: _requestsStream'));

    expect(
      support,
      contains('late final Stream<List<SupportRequest>> _requestsStream'),
    );
    expect(support, contains('stream: _requestsStream'));

    expect(
      issues,
      contains('late final Stream<List<AgentDirectoryEntry>> _agentsStream'),
    );
    expect(issues, contains('stream: _agentsStream'));
    expect(issues, contains('stream: _issuesStream'));

    expect(
      refunds,
      contains('late final Stream<List<RefundCase>> _refundsStream'),
    );
    expect(refunds, contains('stream: _refundsStream'));
  });
}
