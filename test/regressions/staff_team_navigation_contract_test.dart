import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Admin mobile expose Agents Cabinistes et Managers dans Equipe', () {
    final String more = source(
      'lib/features/more/presentation/pages/more_page.dart',
    );

    expect(more, contains("const _SectionLabel('Équipe')"));
    expect(more, contains("title: 'Agents'"));
    expect(more, contains("title: 'Cabinistes'"));
    expect(more, contains("title: 'Managers'"));
    expect(more, contains('ManagerAccountsPage'));
    expect(more, contains('CabinisteFinanceSupervisionPage'));
  });

  test('page mobile Managers expose les informations du compte', () {
    final String managers = source(
      'lib/features/managers/presentation/pages/manager_accounts_page.dart',
    );

    expect(managers, contains("title: 'Comptes Managers'"));
    expect(managers, contains("'Informations du compte'"));
    expect(managers, contains("_detail('E-mail'"));
    expect(managers, contains("'Téléphone secondaire'"));
    expect(managers, contains("'Contact d’urgence'"));
    expect(managers, contains('SupabaseStaffProfileRepository'));
  });

  test('Back Office rend Cabinistes adjacent a Agents dans section Equipe', () {
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
    expect(managers, contains('Voir / gérer le compte'));
  });
}
