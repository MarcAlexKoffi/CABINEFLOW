import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profil Agent reste hydraté si un média Supabase échoue', () {
    final String source = File(
      'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
    ).readAsStringSync();

    final int hydrate = source.indexOf('_hydrateFromSignedInUser();');
    final int profileRead = source.indexOf(
      'repository.fetchProfile(widget.user.id)',
    );

    expect(hydrate, greaterThanOrEqualTo(0));
    expect(profileRead, greaterThan(hydrate));
    expect(source, isNot(contains('Future.wait<Object?>')));
    expect(source, contains('Le profil reste consultable'));
    expect(
      source,
      contains('Certains médias Supabase sont temporairement indisponibles'),
    );
  });

  test('hotfix conserve l’accès Activité détaillée depuis Accueil', () {
    final String home = File(
      'lib/features/agents/presentation/pages/agent_home_page.dart',
    ).readAsStringSync();
    final String shell = File(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    ).readAsStringSync();
    final String profile = File(
      'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
    ).readAsStringSync();

    expect(home, contains("title: 'Mon activité détaillée'"));
    expect(home, contains('onOpenActivity'));
    expect(shell, contains('AgentActivityV2DashboardPage'));
    expect(profile, isNot(contains('AgentActivityV2DashboardPage')));
  });

  test('lectures profil et médias passent par Supabase', () {
    final String profilePage = File(
      'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
    ).readAsStringSync();
    final String repository = File(
      'lib/features/agents/data/repositories/'
      'supabase_agent_personal_profile_repository.dart',
    ).readAsStringSync();

    expect(profilePage, contains('repository.fetchProfile(widget.user.id)'));
    expect(
      profilePage,
      isNot(contains(".collection('agentPersonalProfiles')")),
    );
    expect(repository, contains(".from(tableName)"));
    expect(repository, contains(".storage.from(bucketName)"));
    expect(repository, contains(".eq('firebase_uid', agentId)"));
  });
}
