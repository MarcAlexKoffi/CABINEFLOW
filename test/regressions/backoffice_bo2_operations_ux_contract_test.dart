import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BO-2 - UX operationnelle du back-office', () {
    test('le shell expose un centre de notifications actionnables', () {
      final String shell = File(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      ).readAsStringSync();

      expect(shell, contains('Notifications opérationnelles'));
      expect(shell, contains('watchPaymentTrackingOrders()'));
      expect(shell, contains('watchPaidQueue()'));
      expect(shell, contains('watchOrderHistory()'));
      expect(shell, contains('_BackofficeNotificationButton'));
      expect(shell, contains('Symbols.notifications_rounded'));
    });

    test('les tableaux BO-2 gardent statut et action visibles sans scroll horizontal', () {
      final List<String> paths = <String>[
        'lib/backoffice/presentation/pages/operations/backoffice_orders_page.dart',
        'lib/backoffice/presentation/pages/operations/backoffice_payments_page.dart',
        'lib/backoffice/presentation/pages/operations/backoffice_assignments_page.dart',
        'lib/backoffice/presentation/pages/operations/backoffice_failed_orders_page.dart',
      ];

      for (final String path in paths) {
        final String source = File(path).readAsStringSync();
        expect(source, contains('BackofficeDesktopTable('), reason: path);
        expect(
          source,
          isNot(contains('scrollDirection: Axis.horizontal')),
          reason: path,
        );
        expect(source, isNot(contains('DataTable(')), reason: path);
      }
    });

    test('un paiement a verifier devient prioritaire et visible sans defilement', () {
      final String source = File(
        'lib/backoffice/presentation/pages/operations/backoffice_payments_page.dart',
      ).readAsStringSync();

      expect(source, contains("? 'À vérifier'"));
      expect(source, contains("label: const Text('Voir à vérifier')"));
      expect(source, contains('aActionable != bActionable'));
      expect(source, contains('accentColor: actionable ? BackofficePalette.warning'));
      expect(source, contains("label: const Text('Vérifier')"));
    });

    test('les mini statistiques BO-2 utilisent le format compact', () {
      final String widgets = File(
        'lib/backoffice/presentation/widgets/backoffice_order_widgets.dart',
      ).readAsStringSync();

      expect(
        widgets,
        contains('padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13)'),
      );
      expect(widgets, contains('width: 34'));
      expect(widgets, contains('fontSize: 21'));

      final List<String> pages = <String>[
        'backoffice_orders_page.dart',
        'backoffice_payments_page.dart',
        'backoffice_assignments_page.dart',
        'backoffice_failed_orders_page.dart',
      ];
      for (final String file in pages) {
        final String source = File(
          'lib/backoffice/presentation/pages/operations/$file',
        ).readAsStringSync();
        expect(source, contains('constraints.maxWidth >= 920'), reason: file);
        expect(source, contains('final double gap = 10'), reason: file);
      }
    });
  });
}
