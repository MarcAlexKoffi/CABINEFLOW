import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Repository charge une simulation Manager sans écriture financière', () {
    final String repository = source(
      'lib/features/team/data/repositories/supabase_team_supervision_repository.dart',
    );

    expect(repository, contains("'izytel_manager_compensation_preview'"));
    expect(repository, contains("finance['compensationPreview']"));

    // La consultation de la projection ne doit jamais activer
    // ni comptabiliser automatiquement une rémunération.
    expect(repository, isNot(contains('activateManagerCompensationPlan')));
    expect(repository, isNot(contains('bookManagerCompensation')));
  });

  test(
    'Performance Manager affiche rémunération théorique, éligibilité et seuils',
    () {
      final String page = source(
        'lib/features/team/presentation/pages/team_performance_page.dart',
      );

      expect(page, contains("'Rémunération du mois'"));

      // Activité supervisée.
      expect(page, contains("activity['izytelGrossGain']"));
      expect(page, contains("activity['completedOrders']"));
      expect(page, contains("activity['averageDailyOrders']"));

      // Nouvelle distinction théorique / éligible.
      expect(page, contains("projection['theoreticalVariableAmount']"));
      expect(page, contains("projection['theoreticalTotalAmount']"));
      expect(page, contains("projection['eligibleTotalAmount']"));
      expect(page, contains("eligibility['eligible']"));

      // Seuils d'activation.
      expect(page, contains("plan['activationGrossThreshold']"));
      expect(page, contains("plan['activationDailyOrderThreshold']"));

      // Le brouillon ne crée aucune dette réelle.
      expect(page, contains('aucune dette IzyTel'));
    },
  );

  test(
    'Fiche Manager distingue rémunération théorique et rémunération éligible',
    () {
      final String page = source(
        'lib/features/team/presentation/pages/team_member_detail_page.dart',
      );

      expect(page, contains("title: 'Rémunération Manager'"));

      expect(page, contains("'Rémunération théorique'"));
      expect(page, contains("'Rémunération éligible'"));

      expect(page, contains('theoreticalTotalAmount'));
      expect(page, contains('eligibleTotalAmount'));

      expect(page, contains("eligible ? 'Seuils atteints' : 'Non éligible'"));

      // Tant que le plan reste en draft, les montants
      // théoriques ne constituent pas une dette IzyTel.
      expect(page, contains('ne constituent pas une dette IzyTel'));
    },
  );

  test('Rafraîchissement recharge aussi la simulation Manager', () {
    final String page = source(
      'lib/features/team/presentation/pages/team_performance_page.dart',
    );

    expect(page, contains('_managerCompensationPreviewFuture'));
    expect(page, contains('nextPreview'));

    // Le Future doit être préparé avant le setState,
    // pas recréé directement à l'intérieur.
    expect(
      page,
      isNot(contains('setState(() => _managerCompensationPreviewFuture')),
    );
  });
}
