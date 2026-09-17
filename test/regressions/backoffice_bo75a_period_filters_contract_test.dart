import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('BO-7.5A1 - filtres périodiques Web et calendrier historique', () {
    test('le filtre partagé propose les périodes rapides et un vrai calendrier ancien', () {
      final String source = _read('lib/shared/widgets/izytel_period_filter.dart');
      expect(source, contains('enum IzyTelPeriodPreset'));
      expect(source, contains('IzyTelPeriodPreset.today'));
      expect(source, contains('IzyTelPeriodPreset.last7Days'));
      expect(source, contains('IzyTelPeriodPreset.last30Days'));
      expect(source, contains('IzyTelPeriodPreset.currentMonth'));
      expect(source, contains('IzyTelPeriodPreset.custom'));
      expect(source, contains('showDateRangePicker'));
      expect(source, contains('DateTime(2000, 1, 1)'));
      expect(source, contains("calendarHelpText"));
    });

    test('le journal et audit chargent les anciennes périodes côté serveur', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/control/backoffice_control_page.dart',
      );
      final String repository = _read(
        'lib/features/control/data/repositories/supabase_control_repository.dart',
      );
      expect(page, contains('fetchActivityPage'));
      expect(page, contains('fetchAuditPage'));
      expect(page, contains("calendarHelpText: 'Rechercher une ancienne activité'"));
      expect(repository, contains("'izytel_bo75_control_activity_page'"));
      expect(repository, contains("'izytel_bo75_control_audit_page'"));
      expect(repository, contains("'p_start'"));
      expect(repository, contains("'p_end'"));
    });

    test('les centres opérationnels Web combinent leurs filtres métier et la période', () {
      final List<String> paths = <String>[
        'lib/backoffice/presentation/pages/operations/backoffice_orders_page.dart',
        'lib/backoffice/presentation/pages/operations/backoffice_payments_page.dart',
        'lib/backoffice/presentation/pages/operations/backoffice_assignments_page.dart',
        'lib/backoffice/presentation/pages/operations/backoffice_failed_orders_page.dart',
      ];
      for (final String path in paths) {
        final String source = _read(path);
        expect(source, contains('IzyTelPeriodFilterBar'), reason: path);
        expect(source, contains('_period.contains'), reason: path);
      }
    });

    test('les centres Clients et Signalements respectent également la période', () {
      final List<String> paths = <String>[
        'lib/backoffice/presentation/pages/clients/backoffice_support_requests_page.dart',
        'lib/backoffice/presentation/pages/clients/backoffice_refunds_page.dart',
        'lib/backoffice/presentation/pages/team/backoffice_agent_issues_page.dart',
      ];
      for (final String path in paths) {
        final String source = _read(path);
        expect(source, contains('IzyTelPeriodFilterBar'), reason: path);
        expect(source, contains('_period'), reason: path);
      }
    });
  });
}
