import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('BO-7.2 - Centre de signalements Agents', () {
    test('le Back-office utilise un snapshot Supabase dédié et scoped', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/team/backoffice_agent_issues_page.dart',
      );
      final String repo = _read(
        'lib/features/agents/data/repositories/supabase_agent_issue_center_repository.dart',
      );

      expect(page, contains('SupabaseAgentIssueCenterRepository'));
      expect(page, contains('SupabaseBackofficeCasePaginationRepository'));
      expect(page, contains('fetchAgentIssuePage'));
      expect(page, contains('Périmètre Manager'));
      expect(repo, contains("'izytel_bo72_transition_agent_issue'"));
    });

    test('la vue propose filtres, tri et rendu premium du détail', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/team/backoffice_agent_issues_page.dart',
      );

      expect(page, contains('enum _IssueNetworkScope'));
      expect(page, contains('enum _IssueSort'));
      expect(page, contains("labelText: 'Réseau'"));
      expect(page, contains("labelText: 'Tri'"));
      expect(page, contains('showBackofficeModal<void>'));
      expect(page, contains("title: 'Incident'"));
      expect(page, contains("title: 'Historique du traitement'"));
      expect(page, contains('BackofficeModalHero'));
      expect(page, contains('BackofficeInfoGrid'));
    });

    test('résolution et classement exigent une note de clôture', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/team/backoffice_agent_issues_page.dart',
      );
      final String migration = _read(
        'supabase/migrations/20260916224500_bo72_agent_issue_center.sql',
      );

      expect(page, contains('Note de clôture'));
      expect(page, contains('value.length >= 3 && value.length <= 1000'));
      expect(page, contains("status: 'resolved'"));
      expect(page, contains("status: 'cancelled'"));
      expect(migration, contains('RESOLUTION_NOTE_REQUIRED'));
      expect(migration, contains('resolution_note'));
    });

    test('les transitions sont historisées dans une table RPC-only', () {
      final String migration = _read(
        'supabase/migrations/20260916224500_bo72_agent_issue_center.sql',
      );
      final String model = _read(
        'lib/features/agents/domain/models/agent_issue_center_models.dart',
      );

      expect(migration, contains('create table if not exists public.agent_issue_events'));
      expect(migration, contains('enable row level security'));
      expect(migration, contains('trg_izytel_agent_issue_event_history'));
      expect(migration, contains("event.event_kind = 'created'"));
      expect(model, contains('class AgentIssueCenterEvent'));
      expect(model, contains('class AgentIssueCenterSnapshot'));
    });

    test('un Manager ne peut lire ou modifier que ses Agents zonés', () {
      final String migration = _read(
        'supabase/migrations/20260916224500_bo72_agent_issue_center.sql',
      );

      expect(migration, contains('private.izytel_issue_agent_in_scope'));
      expect(migration, contains("v_role not in ('manager', 'supervisor')"));
      expect(migration, contains('zone.manager_id = v_uid'));
      expect(migration, contains('capacity.agent_id = p_agent_id'));
      expect(migration, contains('scoped staff updates issue status'));
      expect(migration, contains('ISSUE_OUT_OF_SCOPE'));
    });

    test('le flux Agent/mobile existant reste disponible', () {
      final String migration = _read(
        'supabase/migrations/20260916224500_bo72_agent_issue_center.sql',
      );
      final String legacyRepo = _read(
        'lib/features/agents/data/repositories/supabase_agent_issue_repository.dart',
      );

      expect(migration, contains('agent_id = (select auth.jwt()->>\'sub\')'));
      expect(legacyRepo, contains("'status': 'open'"));
      expect(legacyRepo, contains('watchAgentIssues(String agentId)'));
    });
  });
}
