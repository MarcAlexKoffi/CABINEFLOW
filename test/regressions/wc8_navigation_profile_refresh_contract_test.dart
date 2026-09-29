import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC8 - navigation native et refresh Agent borne', () {
    test('Web client: messagerie est une vraie route et retour interne est local', () {
      final String flow = File(
        'lib/features/customer_order/presentation/pages/customer_order_flow_page.dart',
      ).readAsStringSync();
      final String messaging = File(
        'lib/features/messaging/presentation/pages/customer_messaging_page.dart',
      ).readAsStringSync();

      expect(flow, contains('_pushMessagingRoute'));
      expect(flow, contains("RouteSettings(name: '/customer/messaging')"));
      expect(flow, contains('MaterialPageRoute<void>('));
      expect(flow, contains('Navigator.of(routeContext).maybePop()'));
      expect(messaging, contains("RouteSettings(name: '/customer/messaging/new')"));
      expect(messaging, contains("'/customer/messaging/conversation/"));
      expect(messaging, contains('_pushMobileComposerRoute'));
      expect(messaging, contains('_pushMobileConversationRoute'));
      expect(messaging, isNot(contains('PopScope(')));
    });

    test('Mobile staff: le retour Android est transactionnel dans le shell', () {
      final String shell = File(
        'lib/features/navigation/presentation/pages/main_shell_page.dart',
      ).readAsStringSync();

      expect(shell, contains('PopScope('));
      expect(shell, contains('canPop: false'));
      expect(shell, contains('currentNavigator.canPop()'));
      expect(shell, contains('await currentNavigator.maybePop()'));
      expect(shell, contains('Duration(milliseconds: 250)'));
      expect(shell, isNot(contains('NavigatorPopHandler<Object?>')));
      expect(shell, isNot(contains('IzyTelMobileBackScope(')));
    });

    test('Profil Agent: le pull-to-refresh ne redemarre plus les streams', () {
      final String page = File(
        'lib/features/agents/presentation/pages/agent_activity_page.dart',
      ).readAsStringSync();
      final String viewModel = File(
        'lib/features/agents/presentation/view_models/agent_activity_view_model.dart',
      ).readAsStringSync();

      expect(page, contains('onRefresh: _viewModel.refresh'));
      expect(page, isNot(contains('onRefresh: _viewModel.start')));
      expect(viewModel, contains('Future<void> refresh() async'));
      expect(viewModel, contains('const Duration timeout = Duration(seconds: 6)'));
      expect(viewModel, contains('.first'));
      expect(viewModel, contains('.timeout(timeout)'));
      expect(viewModel, contains('if (_isDisposed) return;'));
    });
  });
}
