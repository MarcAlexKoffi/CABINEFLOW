import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('BO-7.5B1a - pagination serveur Clients, Signalements et Controle', () {
    test('la pagination partagee expose tailles, compteurs et navigation', () {
      final String source = _read(
        'lib/backoffice/presentation/widgets/backoffice_pagination.dart',
      );
      expect(source, contains('class BackofficePaginationBar'));
      expect(source, contains("Text('25 / page')"));
      expect(source, contains("Text('50 / page')"));
      expect(source, contains("Text('100 / page')"));
      expect(source, contains("label: const Text('Précédent')"));
      expect(source, contains("label: const Text('Suivant')"));
    });

    test('demandes clients et remboursements utilisent les RPC pagines', () {
      final String repo = _read(
        'lib/backoffice/data/repositories/supabase_backoffice_case_pagination_repository.dart',
      );
      final String support = _read(
        'lib/backoffice/presentation/pages/clients/backoffice_support_requests_page.dart',
      );
      final String refunds = _read(
        'lib/backoffice/presentation/pages/clients/backoffice_refunds_page.dart',
      );

      expect(repo, contains("'izytel_bo75b1_support_page'"));
      expect(repo, contains("'izytel_bo75b1_refunds_page'"));
      expect(repo, contains("'p_offset': (page - 1) * pageSize"));
      expect(repo, contains("'p_limit': pageSize"));
      expect(support, contains('fetchSupportPage'));
      expect(support, contains('BackofficePaginationBar'));
      expect(support, isNot(contains('watchAllRequests')));
      expect(refunds, contains('fetchRefundPage'));
      expect(refunds, contains('BackofficePaginationBar'));
      expect(refunds, isNot(contains('watchAll()')));
    });

    test('signalements gardent le scope Manager et paginent apres filtres', () {
      final String repo = _read(
        'lib/backoffice/data/repositories/supabase_backoffice_case_pagination_repository.dart',
      );
      final String page = _read(
        'lib/backoffice/presentation/pages/team/backoffice_agent_issues_page.dart',
      );
      final String migration = _read(
        'supabase/migrations/20260917022652_bo75b1a_issue_search_agent_identity.sql',
      );

      expect(repo, contains("'izytel_bo75b1_agent_issues_page'"));
      expect(page, contains('fetchAgentIssuePage'));
      expect(page, contains('BackofficePaginationBar'));
      expect(page, contains('IzyTelPeriodFilterBar'));
      expect(page, contains("_IssueNetworkScope.orange => 'orange'"));
      expect(migration, contains('private.izytel_issue_agent_in_scope(i.agent_id)'));
      expect(migration, contains('phase5_agent_capacities'));
      expect(migration, contains('offset v_offset limit v_limit'));
    });

    test('journal et audit utilisent toujours leurs RPC serveur avec offset et limit', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/control/backoffice_control_page.dart',
      );
      final String repository = _read(
        'lib/features/control/data/repositories/supabase_control_repository.dart',
      );

      expect(page, contains('offset: (_page - 1) * _pageSize'));
      expect(page, contains('limit: _pageSize'));
      expect(page, contains('BackofficePaginationBar'));
      expect(page, contains('query: _query'));
      expect(page, contains('domain: _domain.rpcValue'));
      expect(repository, contains("'izytel_bo75_control_activity_page'"));
      expect(repository, contains("'izytel_bo75_control_audit_page'"));
    });

    test('les RPC Clients valident le staff avant de lire les donnees', () {
      final String migration = _read(
        'supabase/migrations/20260917022335_bo75b1a_server_pagination_cases.sql',
      );
      expect(migration, contains('private.is_izytel_finance_staff()'));
      expect(migration, contains("raise exception 'STAFF_REQUIRED'"));
      expect(migration, contains('security definer'));
      expect(migration, contains('to anon, authenticated'));
    });
  });
}
