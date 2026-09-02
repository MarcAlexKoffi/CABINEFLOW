import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profil Agent reste hydraté si un média Firestore échoue', () {
    final String source = File(
      'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
    ).readAsStringSync();

    final int hydrate = source.indexOf('_hydrateFromSignedInUser();');
    final int profileRead = source.indexOf(
      ".collection('agentPersonalProfiles')",
    );

    expect(hydrate, greaterThanOrEqualTo(0));
    expect(profileRead, greaterThan(hydrate));
    expect(source, isNot(contains('Future.wait<Object?>')));
    expect(source, contains('Les informations du compte restent affichées.'));
    expect(
      source,
      contains('Certains médias du profil sont temporairement indisponibles'),
    );
  });

  test('hotfix conserve l’accès Activité détaillée depuis Accueil', () {
    final String home = File(
      'lib/features/agents/presentation/pages/agent_home_page.dart',
    ).readAsStringSync();
    final String profile = File(
      'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
    ).readAsStringSync();

    expect(home, contains('AgentActivityV2DashboardPage'));
    expect(home, contains("title: 'Mon activité détaillée'"));
    expect(profile, isNot(contains('AgentActivityV2DashboardPage')));
  });

  test('lectures profil et médias restent documentaires', () {
    final String profilePage = File(
      'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
    ).readAsStringSync();
    final String mediaRepository = File(
      'lib/features/agents/data/repositories/'
      'firestore_agent_personal_media_repository.dart',
    ).readAsStringSync();

    expect(profilePage, contains(".collection('agentPersonalProfiles')"));
    expect(profilePage, contains('.doc(widget.user.id)'));
    expect(mediaRepository, contains(".collection('agentPersonalMedia')"));
    expect(mediaRepository, contains('.doc(agentId)'));
    expect(mediaRepository, contains('.doc(kind.firestoreValue)'));
  });
}
