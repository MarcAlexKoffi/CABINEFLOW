import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC6 - registre Managers et création de zone', () {
    test('le repository provisionne les Managers Firestore dans Supabase', () {
      final String repository = File(
        'lib/backoffice/data/repositories/supabase_territory_repository.dart',
      ).readAsStringSync();
      expect(repository, contains("collection('users').get()"));
      expect(repository, contains("role != 'manager' && role != 'supervisor'"));
      expect(repository, contains("izytel_wc6_provision_manager_account"));
    });

    test('Zones synchronise le registre Manager avant le sélecteur', () {
      final String zones = File(
        'lib/backoffice/presentation/pages/team/backoffice_zones_page.dart',
      ).readAsStringSync();
      expect(zones, contains('syncManagersFromStaffRegistry()'));
      expect(zones, contains("labelText: 'Manager responsable'"));
    });

    test('Utilisateurs propose un accès direct à Comptes Managers', () {
      final String users = File(
        'lib/backoffice/presentation/pages/backoffice_users_page.dart',
      ).readAsStringSync();
      final String shell = File(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      ).readAsStringSync();
      expect(users, contains('Gérer dans Comptes Managers'));
      expect(users, contains('Gérer dans Agents'));
      expect(shell, contains('onManageManager'));
      expect(shell, contains('onManageAgent'));
      expect(shell, contains('BackofficeDestination.managers'));
      expect(shell, contains('BackofficeDestination.agents'));
    });

    test('la migration garde le contrôle Admin et autorise les JWT Firebase', () {
      final String sql = File(
        'supabase/migrations/20260927155000_wc6_manager_registry_zone_creation_fix.sql',
      ).readAsStringSync();
      expect(sql, contains('private.is_izytel_finance_admin()'));
      expect(sql, contains('izytel_wc6_provision_manager_account'));
      expect(sql, contains('to anon, authenticated, service_role'));
      expect(sql, contains('izytel_wc5_create_territory_zone'));
      expect(sql, contains('izytel_wc5_update_territory_zone'));
    });
  });
}
