import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC12 - Web Client navigation retour reelle', () {
    late String flow;

    setUpAll(() {
      flow = File(
        'lib/features/customer_order/presentation/pages/customer_order_flow_page.dart',
      ).readAsStringSync();
    });

    test('les boutons Retour restaurent la pile IzyTel sans history.back', () {
      final int start = flow.indexOf('  void _requestBack() {');
      final int end = flow.indexOf('\n  void _replaceWithHome() {', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));

      final String requestBack = flow.substring(start, end);
      expect(requestBack, contains('_resolveBackTarget()'));
      expect(requestBack, contains('_restoreHistoryEntry(previous);'));
      expect(requestBack, contains('_webHistory.replace(previous);'));
      expect(requestBack, isNot(contains('_webHistory.back();')));
    });

    test('le Retour navigateur ne peut plus sauter plusieurs niveaux', () {
      expect(flow, contains('_findNavigationEntryIndex(entry)'));
      expect(flow, contains('entry.matches(expectedPrevious)'));
      expect(flow, contains('_restoreHistoryEntry(expectedPrevious);'));
      expect(flow, contains('_webHistory.push(expectedPrevious);'));
      expect(
        flow,
        contains('current.step == CustomerOrderViewModel.totalSteps'),
      );
    });

    test('toutes les etapes commande utilisent le meme retour centralise', () {
      expect(flow, contains('onBackToHome: _requestBack'));
      expect(
        RegExp(r'onBack: _requestBack').allMatches(flow).length,
        greaterThanOrEqualTo(6),
      );

      final String summary = File(
        'lib/features/customer_order/presentation/pages/customer_summary_page.dart',
      ).readAsStringSync();
      expect(summary, contains("backLabel: orderCreated ? 'Commande enregistrée' : 'Modifier'"));
      expect(summary, contains('widget.onBack ?? widget.viewModel.goBack'));
    });

    test('Aide conserve Messagerie et Recuperation comme sous-routes', () {
      expect(flow, contains("RouteSettings(name: '/customer/messaging')"));
      expect(flow, contains("RouteSettings(name: '/customer/recovery')"));
      expect(flow, contains('_messagingRouteActive || _recoveryRouteActive'));
    });
  });
}
