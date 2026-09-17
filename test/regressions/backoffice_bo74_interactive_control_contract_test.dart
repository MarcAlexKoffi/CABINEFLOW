import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('BO-7.4 - Journal interactif et audit détaillé', () {
    test('le journal est recherchable, filtrable et chaque événement est cliquable', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/control/backoffice_control_page.dart',
      );

      expect(page, contains('enum _ActivityDomainFilter'));
      expect(page, contains("hintText: 'Rechercher une référence, un Agent, un événement…'"));
      expect(page, contains("labelText: 'Domaine'"));
      expect(page, contains('class _EventCard extends StatelessWidget'));
      expect(page, contains('required this.onTap'));
      expect(page, contains('InkWell('));
      expect(page, contains('onTap: onTap'));
    });

    test('le détail activité utilise les modals premium et expose les données métier', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/control/backoffice_control_page.dart',
      );

      expect(page, contains('showBackofficeModal<void>'));
      expect(page, contains('BackofficeModalShell('));
      expect(page, contains('BackofficeModalHero('));
      expect(page, contains("title: 'Données associées'"));
      expect(page, contains('IzyTelOperatorLogo'));
      expect(page, contains("label: const Text('Ouvrir le module lié')"));
    });

    test('le shell route les événements vers leur module existant sans contourner les permissions', () {
      final String shell = _read(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      );

      expect(shell, contains('void _openActivityModule(ControlActivityEvent event)'));
      expect(shell, contains("'payments' => BackofficeDestination.payments"));
      expect(shell, contains("'assignments' => BackofficeDestination.assignments"));
      expect(shell, contains("'support' => BackofficeDestination.customerRequests"));
      expect(shell, contains("'agents' => BackofficeDestination.agentIssues"));
      expect(shell, contains("'refunds' => BackofficeDestination.refunds"));
      expect(shell, contains('destination.visibleFor(widget.user)'));
      expect(shell, contains('onOpenActivityModule: _openActivityModule'));
    });

    test('l’audit reste réservé à l’Admin mais ses lignes deviennent inspectables', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/control/backoffice_control_page.dart',
      );

      expect(page, contains("title: 'Audit réservé à l’Administrateur'"));
      expect(page, contains('auditAllowed'));
      expect(page, contains('class _AuditEventCard extends StatelessWidget'));
      expect(page, contains('_showAuditDetail(context, event)'));
      expect(page, contains("title: 'Données auditées'"));
      expect(page, contains("title: 'Traçabilité'"));
    });

    test('aucune nouvelle permission backend ou écriture métier n’est introduite', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/control/backoffice_control_page.dart',
      );

      expect(page, isNot(contains('Supabase.instance.client.from(')));
      expect(page, isNot(contains('.insert(')));
      expect(page, isNot(contains('.update(')));
      expect(page, isNot(contains('.delete(')));
    });
  });
}
