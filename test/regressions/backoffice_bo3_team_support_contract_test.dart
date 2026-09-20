import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BO-3 - équipe et support Back-office', () {
    test('Support et Remboursements utilisent Supabase comme source operationnelle', () {
      final String app = File('lib/backoffice/backoffice_app.dart').readAsStringSync();
      final String supportFactory = File(
        'lib/features/support/data/repositories/operational_support_request_repository.dart',
      ).readAsStringSync();
      final String refundFactory = File(
        'lib/features/refunds/data/repositories/operational_refund_repository.dart',
      ).readAsStringSync();

      expect(app, contains('createOperationalSupportRequestRepository()'));
      expect(app, contains('createOperationalRefundRepository()'));
      expect(app, contains('supportRepository: widget.supportRepository'));
      expect(app, contains('refundRepository: widget.refundRepository'));
      expect(supportFactory, contains('SupabaseSupportRequestRepository()'));
      expect(refundFactory, contains('SupabaseRefundRepository()'));
      expect(app, isNot(contains('FirestoreSupportRequestRepository()')));
      expect(app, isNot(contains('FirestoreRefundRepository()')));
    });

    test('les destinations BO-3 ne sont plus des placeholders', () {
      final String shell = File(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      ).readAsStringSync();
      expect(shell, contains('BackofficeSupportRequestsPage('));
      expect(shell, contains('BackofficeRefundsPage('));
      expect(shell, contains('BackofficeAgentsPage('));
      expect(shell, contains('BackofficeManagersPage('));
      expect(shell, contains('BackofficeZonesPage('));
      expect(shell, contains('BackofficeAgentIssuesPage('));
    });

    test('Demandes clients réutilise le repository et ses actions métier', () {
      final String source = File(
        'lib/backoffice/presentation/pages/clients/backoffice_support_requests_page.dart',
      ).readAsStringSync();
      expect(source, contains('fetchSupportPage'));
      expect(source, contains('SupabaseBackofficeCasePaginationRepository'));
      expect(source, contains('BackofficePaginationBar'));
      expect(source, isNot(contains('watchAllRequests()')));
      expect(source, contains('takeInCharge('));
      expect(source, contains('repository.resolve('));
      expect(source, contains('markCustomerNotified('));
      expect(source, contains('repository.close('));
      expect(source, contains('canProcessSupportRequests'));
    });

    test('Remboursements conserve validation exécution notification et rapprochement', () {
      final String source = File(
        'lib/backoffice/presentation/pages/clients/backoffice_refunds_page.dart',
      ).readAsStringSync();
      expect(source, contains('fetchRefundPage'));
      expect(source, contains('SupabaseBackofficeCasePaginationRepository'));
      expect(source, contains('BackofficePaginationBar'));
      expect(source, isNot(contains('watchAll()')));
      expect(source, contains('repository.approve('));
      expect(source, contains('repository.markRefunded('));
      expect(source, contains('repository.markCustomerNotified('));
      expect(source, contains('repository.reconcile('));
      expect(source, contains('repository.reject('));
    });

    test('Agents expose annuaire réseaux capacités zones et gestion Admin', () {
      final String source = File(
        'lib/backoffice/presentation/pages/team/backoffice_agents_page.dart',
      ).readAsStringSync();
      expect(source, contains('watchAgents()'));
      expect(source, contains('watchZones()'));
      expect(source, contains('saveAgentAdmin('));
      expect(source, contains('authorizedNetworks'));
      expect(source, contains('orangeCapacity'));
      expect(source, contains('canManageAgents'));
    });

    test('Zones utilise le référentiel territorial Supabase et les Agents existants', () {
      final String source = File(
        'lib/backoffice/presentation/pages/team/backoffice_zones_page.dart',
      ).readAsStringSync();
      expect(source, contains('territoryRepository.fetchZones()'));
      expect(source, contains('territoryRepository.fetchManagers()'));
      expect(source, contains('agentRepository.watchAgents().first'));
      expect(source, contains('territoryRepository.createZone('));
      expect(source, contains('territoryRepository.updateZone('));
      expect(source, contains('FlutterMap('));
      expect(source, contains('tile.openstreetmap.org'));
    });

    test('Signalements Agents garde le workflow open in_progress resolved cancelled', () {
      final String source = File(
        'lib/backoffice/presentation/pages/team/backoffice_agent_issues_page.dart',
      ).readAsStringSync();
      expect(source, contains('fetchAgentIssuePage'));
      expect(source, contains('BackofficePaginationBar'));
      expect(source, contains('_centerRepository.transitionIssue('));
      expect(source, isNot(contains('watchAllAgentIssues()')));
      expect(source, contains("'in_progress'"));
      expect(source, contains("'resolved'"));
      expect(source, contains("'cancelled'"));
    });

    test('le centre de notifications couvre désormais les alertes BO-3', () {
      final String shell = File(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      ).readAsStringSync();
      expect(shell, contains('Backoffice.notifications.support'));
      expect(shell, contains('Backoffice.notifications.agent-issues'));
      expect(shell, contains('Backoffice.notifications.refunds'));
      expect(shell, contains('demande'));
      expect(shell, contains('signalement'));
      expect(shell, contains('remboursement'));
    });
  });
}
