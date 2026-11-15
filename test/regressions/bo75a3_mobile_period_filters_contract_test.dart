import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('le filtre periodique partage couvre le calendrier historique', () {
    final String source = read(
      'lib/app/shared/widgets/izytel_period_filter.dart',
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
      'lib/app/modules/agent_orders/views/agent_history_page.dart',
    );
    final String commissions = read(
      'lib/app/modules/commissions/views/agent_commissions_page.dart',
    );
    final String ownIssues = read(
      'lib/app/modules/agent_issues/views/agent_issues_page.dart',
    );
    final String issueCenter = read(
      'lib/app/modules/agent_issues/views/agent_issue_center_page.dart',
    );
    final String payments = read(
      'lib/app/modules/payments/views/payments_page.dart',
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
      'lib/app/modules/control/views/admin_activity_journal_page.dart',
    );
    final String movements = read(
      'lib/app/modules/finance/views/financial_movements_page.dart',
    );
    final String refunds = read(
      'lib/app/modules/refunds/views/refund_management_page.dart',
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
      'lib/app/domain/entities/orders/order_history_filters.dart',
    );
    final String page = read(
      'lib/app/modules/staff_history/views/order_history_page.dart',
    );
    final String viewModel = read(
      'lib/app/modules/staff_history/controllers/order_history_view_model.dart',
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
