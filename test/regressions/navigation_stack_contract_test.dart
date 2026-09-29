import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('system back is centralized in each mobile shell with a gesture lock', () {
    final String shell = source(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );

    expect(shell, contains('PopScope('));
    expect(shell, contains('canPop: false'));
    expect(shell, contains('currentNavigator.canPop()'));
    expect(shell, contains('await currentNavigator.maybePop()'));
    expect(shell, contains('if (_selectedIndex != 0)'));
    expect(shell, contains('Duration(seconds: 2)'));
    expect(
      RegExp(r'Duration\(milliseconds: 250\)').allMatches(shell).length,
      greaterThanOrEqualTo(2),
    );
    expect(shell, isNot(contains('NavigatorPopHandler<Object?>')));
    expect(shell, isNot(contains('IzyTelMobileBackScope(')));
  });

  test('bottom tabs preserve independent stacks and reselect pops locally', () {
    final String shell = source(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );

    expect(shell, contains('if (index == _selectedIndex)'));
    expect(shell, contains('void _openRootDestination(int index)'));
    expect(shell, contains('class _IzyTelTabNavigationObserver'));
  });

  test('staff customer history is pushed above detail instead of replacing it', () {
    final String navigation = source(
      'lib/features/orders/presentation/navigation/staff_order_navigation.dart',
    );
    final String orders = source(
      'lib/features/orders/presentation/pages/orders_page.dart',
    );

    expect(navigation, contains('staff-customer-order-history'));
    expect(navigation, contains('context: detailContext'));
    expect(navigation, contains('context: historyContext'));
    expect(navigation, contains('Navigator.of(context).push<void>'));
    expect(orders, isNot(contains('bool _showHistory')));
    expect(orders, isNot(contains('_detailOrder')));
  });

  test('agent order details use real Navigator routes', () {
    final String orders = source(
      'lib/features/orders/presentation/pages/agent_orders_page.dart',
    );
    final String history = source(
      'lib/features/orders/presentation/pages/agent_history_page.dart',
    );

    expect(orders, contains('AgentOrderDetailRoutePage'));
    expect(history, contains('AgentOrderDetailRoutePage'));
    expect(orders, isNot(contains('_openedOrderId')));
    expect(history, isNot(contains('_openedOrderId')));
  });
}
