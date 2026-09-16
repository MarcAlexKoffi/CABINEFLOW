import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('BO-7.3 - sécurité session, signalements, catalogue et alignement', () {
    test('le Back-office Web ferme la session après 15 minutes d’inactivité', () {
      final String app = _read('lib/backoffice/backoffice_app.dart');

      expect(app, contains('Duration(minutes: 15)'));
      expect(app, contains('_BackofficeWebActivityBoundary'));
      expect(app, contains('onPointerDown'));
      expect(app, contains('onPointerSignal'));
      expect(app, contains('onKeyEvent'));
      expect(app, contains('_handleWebInactivity'));
      expect(app, contains('await _logout()'));
      expect(app, contains('if (!kIsWeb) return content;'));
    });

    test('les signalements Agent/Manager retrouvent le droit d’exécuter le scope RLS', () {
      final String migration = _read(
        'supabase/migrations/20260916231644_bo73_catalog_delete_and_issue_scope_fix.sql',
      );

      expect(
        migration,
        contains(
          'grant execute on function private.izytel_issue_agent_in_scope(text)',
        ),
      );
      expect(migration, contains('to anon, authenticated'));
    });

    test('une offre peut être supprimée sans effacer l’historique métier', () {
      final String contract = _read(
        'lib/features/offers/domain/repositories/admin_offer_repository.dart',
      );
      final String repo = _read(
        'lib/features/offers/data/repositories/supabase_admin_offer_repository.dart',
      );
      final String page = _read(
        'lib/backoffice/presentation/pages/catalog/backoffice_offers_page.dart',
      );
      final String migration = _read(
        'supabase/migrations/20260916231644_bo73_catalog_delete_and_issue_scope_fix.sql',
      );

      expect(contract, contains('Future<void> deleteOffer'));
      expect(repo, contains("'izytel_delete_catalog_offer'"));
      expect(repo, contains("row['deleted_at'] != null"));
      expect(page, contains("value == 'delete'"));
      expect(page, contains('Supprimer cette offre ?'));
      expect(page, contains('Supprimer l’offre'));
      expect(migration, contains('deleted_at timestamptz'));
      expect(migration, contains("'deleted'"));
      expect(migration, contains('is_active = false'));
    });

    test('Finances, Contrôle et Pilotage utilisent l’espacement unique du shell', () {
      final String finance = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );
      final String control = _read(
        'lib/backoffice/presentation/pages/control/backoffice_control_page.dart',
      );
      final String shell = _read(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      );

      expect(finance, isNot(contains('EdgeInsets.fromLTRB(24, 22, 24, 40)')));
      expect(control, isNot(contains('EdgeInsets.fromLTRB(28, 22, 28, 36)')));
      expect(shell, contains('desktop ? 30 : 18'));
      expect(shell, contains('BackofficeControlModule.statistics'));
      expect(shell, contains('BackofficeFinanceModule.overview'));
    });
  });
}
