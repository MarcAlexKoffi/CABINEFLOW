import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Repository couvre preview historique clôture validation ajustement paiement', () {
    final String repository = source(
      'lib/features/team/data/repositories/supabase_team_supervision_repository.dart',
    );

    expect(repository, contains("'izytel_manager_compensation_preview'"));
    expect(repository, contains("'izytel_team_member_activity_history'"));
    expect(repository, contains("'izytel_manager_compensation_history'"));
    expect(repository,
        contains("'izytel_admin_close_manager_compensation_period'"));
    expect(repository,
        contains("'izytel_admin_approve_manager_compensation_period'"));
    expect(repository,
        contains("'izytel_admin_adjust_manager_compensation_period'"));
    expect(repository, contains("'izytel_admin_record_manager_payout'"));
  });

  test('Fiche Manager réserve les actions comptables à Admin', () {
    final String page = source(
      'lib/features/team/presentation/pages/team_member_detail_page.dart',
    );

    expect(page, contains('widget.viewer.role == UserRole.administrator'));
    expect(page, contains('Clôturer un mois'));
    expect(page, contains('Approuver la rémunération'));
    expect(page, contains('Ajuster'));
    expect(page, contains('Enregistrer le règlement'));
    expect(page, contains('ManagerCompensationHistoryCard'));
    expect(page, contains('plan Manager est encore en brouillon'));
  });

  test('Historique Manager expose acquis payé dû et statuts mensuels', () {
    final String widget = source(
      'lib/features/team/presentation/widgets/manager_compensation_history_card.dart',
    );

    expect(widget, contains('Historique de rémunération'));
    expect(widget, contains("account['earnedTotal']"));
    expect(widget, contains("account['paidTotal']"));
    expect(widget, contains("account['balanceDue']"));
    expect(widget, contains("status == 'calculated'"));
    expect(widget, contains("status == 'approved'"));
    expect(widget, contains("status == 'paid'"));
  });

  test('Manager voit son historique en lecture seule depuis performance zone', () {
    final String page = source(
      'lib/features/team/presentation/pages/team_performance_page.dart',
    );

    expect(page, contains('_managerCompensationHistoryFuture'));
    expect(page, contains('fetchManagerCompensationHistory'));
    expect(page, contains('ManagerCompensationHistoryCard'));
    expect(page, isNot(contains('adminMode: true')));
  });
}
