import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('file Agent bascule vers la premiere file non vide', () {
    final String viewModel = source(
      'lib/features/orders/presentation/view_models/agent_orders_view_model.dart',
    );

    expect(viewModel, contains('_resolveUsefulTab'));
    expect(viewModel, contains('_syncSelectedTabToAvailableQueue'));
    expect(viewModel, contains('if (toAcceptCount > 0)'));
    expect(viewModel, contains('if (inProgressCount > 0)'));
    expect(viewModel, contains('if (completedCount > 0)'));
  });

  test('file Cabiniste bascule vers la premiere file non vide', () {
    final String shell = source(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    );

    expect(shell, contains('_resolveUsefulTab'));
    expect(shell, contains('effectiveTab'));
    expect(shell, contains('counts[_PartnerOrdersTab.toAccept]'));
    expect(shell, contains('counts[_PartnerOrdersTab.inProgress]'));
    expect(shell, contains('counts[_PartnerOrdersTab.completed]'));
    expect(shell, contains('_filterOrders(allOrders, effectiveTab)'));
  });
}
