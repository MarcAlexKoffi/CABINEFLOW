import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Fiche equipe ouvre sur un apercu compact avec profil et historique a la demande', () {
    final String page = source(
      'lib/features/team/presentation/pages/team_member_detail_page.dart',
    );

    expect(page, contains('_MemberDetailTab.overview'));
    expect(page, contains("label: 'Aperçu'"));
    expect(page, contains("label: 'Profil'"));
    expect(page, contains("label: 'Historique'"));
    expect(page, contains('_compactHeader'));
    expect(page, contains('_collapsibleSection'));
    expect(page, contains('Identité et vérification'));
    expect(page, contains('Informations administratives'));
  });

  test('Apercu Agent distingue mois, cumul et solde du', () {
    final String page = source(
      'lib/features/team/presentation/pages/team_member_detail_page.dart',
    );

    expect(page, contains("teamMap(finance['activityHistory'])"));
    expect(page, contains("teamMap(activityHistory['currentMonth'])"));
    expect(page, contains('Commission du mois'));
    expect(page, contains('Gagné au total'));
    expect(page, contains('Reste à payer'));
    expect(page, contains('Modifier les capacités'));
  });

  test('Apercu Cabiniste garde ses capacites en lecture seule', () {
    final String page = source(
      'lib/features/team/presentation/pages/team_member_detail_page.dart',
    );

    expect(page, contains('Marge Cabiniste'));
    expect(page, contains('Acquis ce mois'));
    expect(page, contains('Déjà reversé'));
    expect(page, contains('fonds de roulement propre du Cabiniste'));
  });

  test('Apercu Manager distingue remuneration theorique et eligible', () {
    final String page = source(
      'lib/features/team/presentation/pages/team_member_detail_page.dart',
    );

    expect(page, contains('Rémunération théorique'));
    expect(page, contains('Rémunération éligible'));
    expect(page, contains("projection['eligibleTotalAmount']"));
    expect(page, contains("eligibility['eligible']"));
    expect(page, contains('Clôturer un mois terminé'));
  });

  test('Liste performance ne confond plus acquis cumule et solde du Agent', () {
    final String page = source(
      'lib/features/team/presentation/pages/team_performance_page.dart',
    );

    expect(page, contains("row['periodCommissionEarned']"));
    expect(page, contains("'Dû \${formatCfa(teamInt(row['commissionDue']))}'"));
    expect(page, contains("row['periodSettlementEarned']"));
    expect(page, contains('Volume du mois'));
    expect(page, contains('Total éligible'));
  });

  test('Repository charge l historique scope Agent Cabiniste', () {
    final String repository = source(
      'lib/features/team/data/repositories/supabase_team_supervision_repository.dart',
    );

    expect(repository, contains("'izytel_team_member_activity_history'"));
    expect(repository, contains("finance['activityHistory']"));
  });
}
