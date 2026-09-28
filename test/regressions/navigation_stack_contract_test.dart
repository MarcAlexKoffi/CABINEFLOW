import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('system back is centralized in the mobile back scope', () {
    final String shell = source(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );
    final String guard = source(
      'lib/features/navigation/presentation/widgets/izytel_mobile_back_scope.dart',
    );

    expect(shell, contains('IzyTelMobileBackScope('));
    expect(guard, contains('PopScope<Object?>'));
    expect(guard, contains('canPop: false'));
    expect(guard, contains('await activeNavigator.maybePop()'));
    expect(guard, contains('if (!widget.isHomeTab)'));
    expect(guard, contains('widget.onReturnHome()'));
    expect(guard, contains('await SystemNavigator.pop()'));
    expect(shell, isNot(contains('NavigatorPopHandler<Object?>')));
  });

  test('bottom tabs preserve independent stacks and reselect pops locally', () {
    final String shell = source(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );

    expect(shell, contains('if (index == _selectedIndex)'));
    expect(shell, contains('// Chaque onglet conserve sa propre pile'));
    expect(shell, contains('void _openRootDestination(int index)'));
    expect(shell, isNot(contains('class _IzyTelTabNavigationObserver')));
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
