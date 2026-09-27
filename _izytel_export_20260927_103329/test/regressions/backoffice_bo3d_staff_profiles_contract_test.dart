import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('BO-3D - Profils Staff communs', () {
    test('Supabase porte une couche canonique Agent Manager Admin', () {
      final String migration = _read(
        'supabase/migrations/20260915001633_bo3d_staff_profiles.sql',
      );

      expect(
        migration,
        contains('create table if not exists public.staff_profiles'),
      );
      expect(
        migration,
        contains('create table if not exists public.staff_profile_audit_events'),
      );
      expect(migration, contains("role in ('admin', 'manager', 'agent')"));
      expect(migration, contains('izytel_save_own_staff_profile'));
      expect(migration, contains('izytel_review_staff_profile'));
      expect(migration, contains('izytel_sync_staff_profiles'));
      expect(migration, contains('trg_agent_profile_to_staff_profile'));
      expect(migration, contains('trg_manager_profile_to_staff_profile'));
      expect(migration, contains('enable row level security'));
      expect(
        migration,
        contains('alter publication supabase_realtime add table public.staff_profiles'),
      );
    });

    test('photo Staff est commune et reste privée dans Supabase Storage', () {
      final String repository = _read(
        'lib/features/auth/data/repositories/supabase_staff_profile_repository.dart',
      );
      final String avatar = _read(
        'lib/features/auth/presentation/widgets/staff_profile_avatar.dart',
      );
      final String managerAvatar = _read(
        'lib/features/auth/presentation/widgets/manager_profile_avatar.dart',
      );
      final String directoryMigration = _read(
        'supabase/migrations/20260915002603_bo3d_staff_avatar_directory_rpc.sql',
      );

      expect(repository, contains("bucketName = 'agent-personal'"));
      expect(repository, contains("'\$uid/avatar/profile.jpg'"));
      expect(repository, contains('izytel_staff_directory_avatar_path'));
      expect(avatar, contains('class StaffProfileAvatar'));
      expect(avatar, contains('ImageSource.gallery'));
      expect(avatar, contains('uploadOwnAvatar('));
      expect(managerAvatar, contains('StaffProfileAvatar('));
      expect(directoryMigration, contains('private.is_izytel_finance_staff()'));
      expect(repository, isNot(contains('FirebaseStorage')));
    });

    test('Back-office Admin expose Mon profil depuis le header', () {
      final String shell = _read(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      );
      final String page = _read(
        'lib/backoffice/presentation/pages/profile/backoffice_my_profile_page.dart',
      );

      expect(shell, contains("value: 'profile'"));
      expect(shell, contains("Text('Mon profil')"));
      expect(shell, contains('BackofficeMyProfilePage(user: user)'));
      expect(shell, contains('StaffProfileAvatar('));
      expect(page, contains('saveOwnProfile('));
      expect(page, contains('editable: true'));
      expect(page, contains('Contact d’urgence'));
      expect(page, contains('Vérification du profil'));
    });

    test('Manager mobile dispose aussi de son profil personnel commun', () {
      final String more = _read(
        'lib/features/more/presentation/pages/more_page.dart',
      );
      final String profile = _read(
        'lib/features/auth/presentation/pages/staff_personal_profile_page.dart',
      );

      expect(more, contains('StaffPersonalProfilePage(user: user)'));
      expect(more, contains("title: 'Mon profil'"));
      expect(profile, contains('SupabaseStaffProfileRepository'));
      expect(profile, contains('StaffProfileAvatar('));
      expect(profile, contains('saveOwnProfile('));
      expect(profile, contains('Contact d’urgence'));
    });

    test('Agent conserve son écran historique mais écrit dans la couche Staff', () {
      final String page = _read(
        'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
      );
      final String adapter = _read(
        'lib/features/agents/data/repositories/'
        'supabase_agent_personal_profile_repository.dart',
      );

      expect(page, contains('SupabaseAgentPersonalProfileRepository'));
      expect(adapter, contains('SupabaseStaffProfileRepository'));
      expect(adapter, contains("staffTableName = SupabaseStaffProfileRepository.tableName"));
      expect(adapter, contains('saveOwnProfile('));
      expect(adapter, isNot(contains("collection('agentPersonalProfiles')")));
      expect(adapter, isNot(contains('WriteBatch')));
    });

    test('Admin voit les dossiers personnels Agent et Manager sans toucher auto-affectation', () {
      final String agents = _read(
        'lib/backoffice/presentation/pages/team/backoffice_agents_page.dart',
      );
      final String managers = _read(
        'lib/backoffice/presentation/pages/team/backoffice_managers_page.dart',
      );

      for (final String source in <String>[agents, managers]) {
        expect(source, contains('DOSSIER PERSONNEL'));
        expect(source, contains('StaffProfileVerificationStatus'));
        expect(source, contains('reviewProfile('));
        expect(source, contains('Voir la pièce d’identité'));
      }
      expect(agents, contains('profile.authorizedNetworks'));
      expect(agents, contains('profile.orangeCapacity'));
      expect(agents, contains('profile.dailyTransactionLimit'));
      expect(agents, contains('profile.maxTransactionsPerDay'));
    });

    test('BO-3D ne crée aucun nouveau flux Firestore', () {
      final List<String> files = <String>[
        'lib/features/auth/data/repositories/supabase_staff_profile_repository.dart',
        'lib/features/auth/presentation/widgets/staff_profile_avatar.dart',
        'lib/features/auth/presentation/pages/staff_personal_profile_page.dart',
        'lib/backoffice/presentation/pages/profile/backoffice_my_profile_page.dart',
      ];
      for (final String path in files) {
        final String source = _read(path);
        expect(source, isNot(contains('FirebaseFirestore')));
        expect(source, isNot(contains(".collection('")));
        expect(source, isNot(contains('WriteBatch')));
      }
    });
  });
}
