import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Performance équipe distingue Admin global et Manager zone', () {
    final String page = source(
      'lib/features/team/presentation/pages/team_performance_page.dart',
    );
    final String repository = source(
      'lib/features/team/data/repositories/supabase_team_supervision_repository.dart',
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
      'lib/features/finances/presentation/pages/finances_page.dart',
    );

    expect(finances, contains("title: 'Finances de ma zone'"));
    expect(finances, contains("title: 'Performance de ma zone'"));
    expect(finances, contains("title: 'Fournisseurs de ma zone'"));
    expect(finances, contains('_teamPerformanceFuture'));
    expect(finances, contains("'Gain IzyTel observé de ma zone'"));
  });

  test('Back Office ouvre les détails financiers équipe', () {
    final String agents = source(
      'lib/backoffice/presentation/pages/team/backoffice_agents_page.dart',
    );
    final String managers = source(
      'lib/backoffice/presentation/pages/team/backoffice_managers_page.dart',
    );
    final String cabinistes = source(
      'lib/backoffice/presentation/pages/finances/backoffice_cabiniste_finance_page.dart',
    );

    expect(agents, contains('Identité, gains et activité'));
    expect(managers, contains('Identité, zone et gains'));
    expect(cabinistes, contains('Identité & activité'));
    expect(agents, contains('TeamMemberDetailPage'));
    expect(managers, contains('TeamMemberDetailPage'));
    expect(cabinistes, contains('TeamMemberDetailPage'));
  });
}
