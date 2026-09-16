import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('BO-7.1 iteration 2 - Modales premium et datavisualisation', () {
    test('le système modal centralise flou, animation et contenu scrollable', () {
      final String modal = _read(
        'lib/backoffice/presentation/widgets/backoffice_modal.dart',
      );
      expect(modal, contains('showGeneralDialog'));
      expect(modal, contains('BackdropFilter'));
      expect(modal, contains('ImageFilter.blur'));
      expect(modal, contains('FadeTransition'));
      expect(modal, contains('ScaleTransition'));
      expect(modal, contains('Flexible('));
      expect(modal, contains('SingleChildScrollView'));
      expect(modal, contains('BackofficeModalSection'));
      expect(modal, contains('BackofficeInfoGrid'));
    });

    test('les modales prioritaires utilisent la couche premium', () {
      final String orders = _read(
        'lib/backoffice/presentation/widgets/backoffice_order_widgets.dart',
      );
      final String users = _read(
        'lib/backoffice/presentation/pages/backoffice_users_page.dart',
      );
      final String payments = _read(
        'lib/backoffice/presentation/pages/operations/backoffice_payments_page.dart',
      );
      final String assignments = _read(
        'lib/backoffice/presentation/pages/operations/backoffice_assignments_page.dart',
      );

      expect(orders, contains('showBackofficeModal<void>'));
      expect(orders, contains('BackofficeModalHero'));
      expect(orders, contains("title: 'Client & bénéficiaire'"));
      expect(orders, contains("title: 'Paiement'"));
      expect(orders, contains("title: 'Affectation & exécution'"));

      expect(users, contains('showBackofficeModal<void>'));
      expect(users, contains("title: 'Identité & contact'"));
      expect(users, contains("title: 'Accès & activité'"));
      expect(users, contains("title: 'Identifiant technique'"));

      expect(payments, contains('showBackofficeModal<String?>'));
      expect(payments, contains("title: 'Vérification du paiement'"));

      expect(assignments, contains('showBackofficeModal<bool>'));
      expect(assignments, contains("title: 'Agents compatibles'"));
    });

    test('les formulaires finance partagent aussi la présentation premium', () {
      final String finance = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );
      expect(finance, contains('showBackofficeModal<bool>'));
      expect(finance, contains('BackofficeModalShell('));
      expect(finance, contains("title: 'Informations'"));
    });

    test('les statistiques utilisent de vrais composants graphiques', () {
      final String charts = _read(
        'lib/backoffice/presentation/widgets/backoffice_charts.dart',
      );
      final String control = _read(
        'lib/backoffice/presentation/pages/control/backoffice_control_page.dart',
      );

      expect(charts, contains('class BackofficeLineChart'));
      expect(charts, contains('class BackofficeDonutChart'));
      expect(charts, contains('class BackofficeHorizontalBarChart'));
      expect(charts, contains('CustomPaint'));
      expect(control, contains("title: 'Évolution de l’activité'"));
      expect(control, contains("title: 'Répartition par réseau'"));
      expect(control, contains("title: 'État des commandes'"));
      expect(control, contains("title: 'Performance des Agents'"));
      expect(control, contains("title: 'Temps moyen de traitement'"));
      expect(control, contains('IzyTelOperatorLogo'));
    });

    test('la tendance journalière reste territoriale pour Manager', () {
      final String migration = _read(
        'supabase/migrations/20260916112000_bo7_daily_statistics_trend.sql',
      );
      final String repo = _read(
        'lib/features/control/data/repositories/supabase_control_repository.dart',
      );
      final String model = _read(
        'lib/features/control/domain/models/control_snapshot.dart',
      );

      expect(migration, contains('izytel_bo7_daily_trend'));
      expect(migration, contains("v_role not in ('admin', 'manager', 'supervisor')"));
      expect(migration, contains('zone.manager_id = v_uid'));
      expect(migration, contains('o.assigned_agent_id = any(v_agent_ids)'));
      expect(migration, contains('greatest(1, least(coalesce(p_days, 30), 30))'));
      expect(repo, contains("'izytel_bo7_daily_trend'"));
      expect(model, contains('class ControlDailyTrend'));
      expect(model, contains("_list(json['daily_trend'])"));
    });

    test('la finance sensible reste conditionnée à auditAllowed', () {
      final String control = _read(
        'lib/backoffice/presentation/pages/control/backoffice_control_page.dart',
      );
      expect(control, contains('if (snapshot.auditAllowed)'));
      expect(control, contains("title: 'Exposition financière Administrateur'"));
      expect(control, contains('ce bloc n’est jamais envoyé aux Managers'));
    });
  });
}
