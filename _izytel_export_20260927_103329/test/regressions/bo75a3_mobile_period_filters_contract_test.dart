import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('le filtre periodique partage couvre le calendrier historique', () {
    final String source = read(
      'lib/shared/widgets/izytel_period_filter.dart',
    );

    expect(source, contains('IzyTelPeriodPreset.last7Days'));
    expect(source, contains('IzyTelPeriodPreset.last30Days'));
    expect(source, contains('IzyTelPeriodPreset.currentMonth'));
    expect(source, contains('showDateRangePicker('));
    expect(source, contains('DateTime(2000, 1, 1)'));
    expect(source, contains("helpText: calendarHelpText"));
  });

  test('Agent et Manager disposent des filtres periodiques mobiles', () {
    final String history = read(
      'lib/features/orders/presentation/pages/agent_history_page.dart',
    );
    final String commissions = read(
      'lib/features/commissions/presentation/pages/agent_commissions_page.dart',
    );
    final String ownIssues = read(
      'lib/features/agents/presentation/pages/agent_issues_page.dart',
    );
    final String issueCenter = read(
      'lib/features/agents/presentation/pages/agent_issue_center_page.dart',
    );
    final String payments = read(
      'lib/features/payments/presentation/pages/payments_page.dart',
    );

    for (final String source in <String>[
      history,
      commissions,
      ownIssues,
      issueCenter,
      payments,
    ]) {
      expect(source, contains('IzyTelPeriodFilterBar('));
      expect(source, contains('IzyTelPeriodFilterValue'));
    }

    expect(history, contains('_syncRechargePeriod'));
    expect(history, contains('_loadRecharges(resetPagination: true)'));
    expect(commissions, contains('periodCommissions'));
    expect(commissions, contains('periodPayouts'));
    expect(issueCenter, contains('periodIssues'));
  });

  test('Admin mobile filtre ses historiques financiers et operationnels', () {
    final String journal = read(
      'lib/features/more/presentation/pages/admin_activity_journal_page.dart',
    );
    final String movements = read(
      'lib/features/finances/presentation/pages/financial_movements_page.dart',
    );
    final String refunds = read(
      'lib/features/refunds/presentation/pages/refund_management_page.dart',
    );

    expect(journal, contains('IzyTelPeriodFilterBar('));
    expect(journal, contains('periodEntries'));
    expect(movements, contains('IzyTelPeriodFilterBar('));
    expect(movements, contains('periodAll'));
    expect(refunds, contains('IzyTelPeriodFilterBar('));
    expect(refunds, contains('_refundActivityDate'));
  });

  test('historique commandes mobile accepte une plage calendrier ancienne', () {
    final String filters = read(
      'lib/features/orders/domain/models/order_history_filters.dart',
    );
    final String page = read(
      'lib/features/orders/presentation/pages/order_history_page.dart',
    );
    final String viewModel = read(
      'lib/features/orders/presentation/view_models/order_history_view_model.dart',
    );

    expect(filters, contains('customStart'));
    expect(filters, contains('customEnd'));
    expect(filters, contains('hasCustomPeriod'));
    expect(page, contains('DateTime(2000, 1, 1)'));
    expect(page, contains("'Calendrier'"));
    expect(page, contains('_pickCustomPeriod'));
    expect(viewModel, contains('_filters.hasCustomPeriod'));
    expect(viewModel, contains('!localCreatedAt.isBefore(start)'));
  });
}
