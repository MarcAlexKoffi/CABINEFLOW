import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('system back follows subpage then home then double exit', () {
    final String shell = source(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );

    expect(shell, contains('await currentNavigator.maybePop()'));
    expect(shell, contains('_popTabToRoot(0)'));
    expect(shell, contains("'Appuie encore une fois pour quitter IzyTel.'"));
    expect(shell, contains('await SystemNavigator.pop()'));
    expect(shell, contains('if (_handlingSystemBack) return;'));
  });

  test('every tab route change disarms the exit double press', () {
    final String shell = source(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );

    expect(shell, contains('class _IzyTelTabNavigationObserver'));
    expect(shell, contains('void didPush('));
    expect(shell, contains('void didPop('));
    expect(shell, contains('void didStartUserGesture('));
    expect(shell, contains('observers: <NavigatorObserver>'));
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
