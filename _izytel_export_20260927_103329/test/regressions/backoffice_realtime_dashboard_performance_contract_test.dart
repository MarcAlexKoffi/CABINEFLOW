import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  group('Back-office - performance, filtres Support et dashboard temps reel', () {
    test('Support et remboursements n utilisent plus un polling toutes les 4 secondes', () {
      final String support = read(
        'lib/features/support/data/repositories/supabase_support_request_repository.dart',
      );
      final String refunds = read(
        'lib/features/refunds/data/repositories/supabase_refund_repository.dart',
      );

      expect(support, contains("stream(primaryKey: const <String>['id'])"));
      expect(refunds, contains("stream(primaryKey: const <String>['order_id'])"));
      expect(support, isNot(contains('_pollInterval')));
      expect(refunds, isNot(contains('_pollInterval')));
      expect(support, isNot(contains('Future<void>.delayed')));
      expect(refunds, isNot(contains('Future<void>.delayed')));
    });

    test('le backfill Firestore historique n est plus relance a chaque connexion Admin', () {
      final String app = read('lib/backoffice/backoffice_app.dart');
      expect(app, isNot(contains('LegacySupportRefundBackfillService')));
      expect(app, isNot(contains('_startLegacyBackfillIfNeeded')));
    });

    test('une demande prise en charge reste visible sans changer manuellement de filtre', () {
      final String page = read(
        'lib/backoffice/presentation/pages/clients/backoffice_support_requests_page.dart',
      );
      expect(page, contains('_SupportScope _scope = _SupportScope.all;'));
      expect(page, contains('if (_scope != _SupportScope.all)'));
      expect(page, contains('setState(() => _scope = _SupportScope.all)'));
    });

    test('le tableau de bord affiche des donnees operationnelles et non les cartes placeholder', () {
      final String dashboard = read(
        'lib/backoffice/presentation/pages/backoffice_dashboard_page.dart',
      );
      final String shell = read(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      );

      expect(dashboard, contains('BackofficeDashboardSnapshot'));
      expect(dashboard, contains('Commandes suivies'));
      expect(dashboard, contains('Paiements à vérifier'));
      expect(dashboard, contains('Demandes clients ouvertes'));
      expect(dashboard, contains('Remboursements à suivre'));
      expect(dashboard, contains('Synchronisation'));
      expect(dashboard, isNot(contains('Mobile conservé')));
      expect(dashboard, isNot(contains('Backends partagés')));
      expect(shell, contains('snapshot: _dashboardSnapshot'));
      expect(shell, contains('completedAmount: completedAmount'));
      expect(shell, contains('openSupportRequests: openSupportRequests'));
    });

    test('la migration publie les deux nouvelles tables dans Supabase Realtime', () {
      final String sql = read(
        'supabase/migrations/20260914203629_support_refunds_realtime_cutover.sql',
      );
      expect(sql, contains('alter publication supabase_realtime add table public.support_requests'));
      expect(sql, contains('alter publication supabase_realtime add table public.refunds'));
    });
  });
}
