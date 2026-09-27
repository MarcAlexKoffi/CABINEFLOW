import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BO-3C - Managers et organisation territoriale', () {
    test('la sidebar expose Managers dans la section Équipe', () {
      final String shell = File(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      ).readAsStringSync();
      expect(shell, contains('BackofficeDestination.managers'));
      expect(shell, contains("return 'Comptes Managers';"));
      expect(shell, contains('Symbols.supervisor_account_rounded'));
      expect(shell, contains('BackofficeManagersPage('));
      expect(shell, contains('territoryRepository: _territoryRepository'));
      expect(
        shell,
        contains('case BackofficeDestination.managers:'),
      );
      expect(shell, contains('return user.role == UserRole.administrator;'));
    });

    test('le module Managers relie zones, Agents et profil opérationnel', () {
      final String managers = File(
        'lib/backoffice/presentation/pages/team/backoffice_managers_page.dart',
      ).readAsStringSync();
      expect(managers, contains('fetchManagers()'));
      expect(managers, contains('fetchZones()'));
      expect(managers, contains('watchAgents().first'));
      expect(managers, contains('syncManagersFromStaffRegistry()'));
      expect(managers, contains('saveManagerProfile('));
      expect(managers, contains('manager.accountActive'));
      expect(managers, contains('manager.isAvailable'));
      expect(managers, contains('Zones supervisées'));
      expect(managers, contains('Agents des zones'));
      expect(managers, contains('ManagerAvatarRepository'));
    });

    test('les zones sont canoniques dans Supabase et conservent le backfill Firestore ponctuel', () {
      final String repository = File(
        'lib/backoffice/data/repositories/supabase_territory_repository.dart',
      ).readAsStringSync();
      final String legacy = File(
        'lib/core/migrations/legacy_territory_backfill_service.dart',
      ).readAsStringSync();
      final String agentRepository = File(
        'lib/features/agents/data/repositories/firestore_agent_repository.dart',
      ).readAsStringSync();
      expect(repository, contains("zonesTable = 'territory_zones'"));
      expect(repository, contains('izytel_create_territory_zone'));
      expect(repository, contains('izytel_update_territory_zone'));
      expect(legacy, contains("collection('zones').get()"));
      expect(legacy, contains('legacyZoneBackfillNeeded()'));
      expect(agentRepository, contains('SupabaseAgentZoneRepository().watchZones()'));
      expect(agentRepository, contains('SupabaseAgentZoneRepository().createZone('));
    });

    test('la carte interactive utilise OpenStreetMap et gère les zones à positionner', () {
      final String zones = File(
        'lib/backoffice/presentation/pages/team/backoffice_zones_page.dart',
      ).readAsStringSync();
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      expect(zones, contains('FlutterMap('));
      expect(zones, contains('MarkerLayer('));
      expect(zones, contains("https://tile.openstreetmap.org/{z}/{x}/{y}.png"));
      expect(zones, contains('© OpenStreetMap contributors'));
      expect(zones, contains('Zones à positionner'));
      expect(zones, contains('Manager responsable'));
      expect(zones, contains('Orange'));
      expect(zones, contains('MTN'));
      expect(zones, contains('Moov'));
      expect(pubspec, contains('flutter_map: ^8.3.2'));
      expect(pubspec, contains('latlong2: ^0.10.1'));
    });

    test('la migration Supabase ajoute RLS, RPC, audit et realtime', () {
      final String migration = File(
        'supabase/migrations/20260914233249_bo3c_territory_managers_zones.sql',
      ).readAsStringSync();
      expect(migration, contains('create table if not exists public.manager_profiles'));
      expect(migration, contains('create table if not exists public.territory_zones'));
      expect(migration, contains('create table if not exists public.territory_audit_events'));
      expect(migration, contains('enable row level security'));
      expect(migration, contains('private.is_izytel_territory_reader()'));
      expect(migration, contains('izytel_save_manager_profile'));
      expect(migration, contains('izytel_import_legacy_zone'));
      expect(migration, contains('alter publication supabase_realtime add table public.territory_zones'));
      expect(migration, contains('alter publication supabase_realtime add table public.manager_profiles'));

      final String hardening = File(
        'supabase/migrations/20260914233828_bo3c_territory_rls_hardening.sql',
      ).readAsStringSync();
      expect(hardening, contains('private.can_read_izytel_territory_zone'));
      expect(hardening, contains('p_zone_id = any(agent.zone_ids)'));

      final String availability = File(
        'supabase/migrations/20260914234259_bo3c_manager_availability_separation.sql',
      ).readAsStringSync();
      expect(availability, contains('is_available boolean'));
      expect(availability, contains('p_is_available boolean'));
      expect(availability, contains('manager.is_available = true'));

      final String scope = File(
        'supabase/migrations/20260914234502_bo3c_manager_territory_scope.sql',
      ).readAsStringSync();
      expect(scope, contains("p_manager_id = (select auth.jwt()->>'sub')"));
      expect(scope, contains('private.can_read_izytel_manager_profile'));

      final String reassignment = File(
        'supabase/migrations/20260914234715_bo3c_zone_manager_reassignment_guard.sql',
      ).readAsStringSync();
      expect(reassignment, contains('is distinct from v_before.manager_id'));
      expect(reassignment, contains('perform private.izytel_assert_manager(v_manager_id)'));
    });

    test('le backfill territorial se déclenche après restauration ou connexion Admin', () {
      final String app = File(
        'lib/backoffice/backoffice_app.dart',
      ).readAsStringSync();
      expect(
        RegExp(r'LegacyTerritoryBackfillService\(\)\.runIfNeeded\(\)').allMatches(app).length,
        greaterThanOrEqualTo(2),
      );
    });
  });
}
