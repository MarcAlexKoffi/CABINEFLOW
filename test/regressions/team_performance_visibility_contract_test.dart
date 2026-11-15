import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Performance équipe distingue Admin global et Manager zone', () {
    final String page = source(
      'lib/app/modules/team/views/team_performance_page.dart',
    );
    final String repository = source(
      'lib/app/data/repositories/supabase_team_supervision_repository.dart',
    );

    expect(page, contains("'Performance de ma zone'"));
    expect(page, contains("'Toutes les zones'"));
    expect(page, contains("const IzyTelSectionHeader(title: 'Agents')"));
    expect(page, contains("const IzyTelSectionHeader(title: 'Cabinistes')"));
    expect(page, contains("const IzyTelSectionHeader(title: 'Managers')"));
    expect(repository, contains("'izytel_team_performance_snapshot'"));
  });

  test('Manager finance utilise la performance de zone et non les commandes globales', () {
    final String finances = source(
      'lib/app/modules/finance/views/finances_page.dart',
    );

    expect(finances, contains("title: 'Finances de ma zone'"));
    expect(finances, contains("title: 'Performance de ma zone'"));
    expect(finances, contains("title: 'Fournisseurs de ma zone'"));
    expect(finances, contains('_teamPerformanceFuture'));
    expect(finances, contains("'Gain IzyTel observé de ma zone'"));
  });

  test('Back Office ouvre les détails financiers équipe', () {
    final String agents = source(
      'lib/app/modules/backoffice/views/team/backoffice_agents_page.dart',
    );
    final String managers = source(
      'lib/app/modules/backoffice/views/team/backoffice_managers_page.dart',
    );
    final String cabinistes = source(
      'lib/app/modules/backoffice/views/finances/backoffice_cabiniste_finance_page.dart',
    );

    expect(agents, contains('Identité, gains et activité'));
    expect(managers, contains('Identité, zone et gains'));
    expect(cabinistes, contains('Identité & activité'));
    expect(agents, contains('TeamMemberDetailPage'));
    expect(managers, contains('TeamMemberDetailPage'));
    expect(cabinistes, contains('TeamMemberDetailPage'));
  });
}
