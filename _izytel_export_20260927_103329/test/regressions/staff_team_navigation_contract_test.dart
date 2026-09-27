import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Admin mobile expose Agents Cabinistes Managers et performance dans Equipe', () {
    final String more = source(
      'lib/features/more/presentation/pages/more_page.dart',
    );

    expect(more, contains("const _SectionLabel('Équipe')"));
    expect(more, contains("title: 'Agents'"));
    expect(more, contains("title: 'Cabinistes'"));
    expect(more, contains("title: 'Managers'"));
    expect(more, contains("title: 'Performance équipe'"));
    expect(more, contains('ManagerAccountsPage(viewer: user)'));
    expect(more, contains('CabinisteFinanceSupervisionPage(viewer: user)'));
    expect(more, contains('TeamPerformancePage(user: user)'));
  });

  test('page mobile Managers ouvre le dossier detaille commun', () {
    final String managers = source(
      'lib/features/managers/presentation/pages/manager_accounts_page.dart',
    );
    final String detail = source(
      'lib/features/team/presentation/pages/team_member_detail_page.dart',
    );

    expect(managers, contains("title: 'Comptes Managers'"));
    expect(managers, contains("actorType: 'manager'"));
    expect(managers, contains('TeamMemberDetailPage'));
    expect(detail, contains("title: 'Coordonnées'"));
    expect(detail, contains("title: 'Identité et vérification'"));
    expect(detail, contains("'Téléphone secondaire'"));
    expect(detail, contains("'Contact d’urgence'"));
    expect(detail, contains("title: 'Performance du mois'"));
    expect(detail, contains("title: 'Rémunération Manager'"));
  });

  test('Back Office rend Cabinistes adjacent a Agents et Managers dans Equipe', () {
    final String shell = source(
      'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
    );
    final String managers = source(
      'lib/backoffice/presentation/pages/team/backoffice_managers_page.dart',
    );

    expect(
      shell,
      contains('agents,\n  cabinisteFinances,\n  managers,'),
    );
    expect(shell, contains("return 'Comptes Managers';"));
    expect(managers, contains('Comptes Managers et supervision territoriale'));
    expect(managers, contains('Identité, zone et gains'));
  });
}
