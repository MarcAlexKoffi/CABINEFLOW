import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('D preserve le hotfix de chargement du profil B2', () {
    final String source = File(
      'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
    ).readAsStringSync();

    expect(source, contains('_hydrateFromSignedInUser();'));
    expect(source, contains('_mediaWarning'));
    expect(source, contains('Certains médias du profil sont temporairement indisponibles'));
    expect(source, contains('AgentCommissionsV2Page'));
  });

  test('D preserve la résilience Activité V2', () {
    final String source = File(
      'lib/features/agents/presentation/pages/agent_activity_v2_dashboard_page.dart',
    ).readAsStringSync();

    expect(source, contains('hasUnavailableSources'));
    expect(source, contains('AgentActivityV2Sources.movements'));
    expect(source, contains('_UnavailableCard'));
    expect(source, contains('Historique complet & statistiques'));
    expect(source, contains('AgentCommissionsV2Page'));
    expect(source, contains('AdminAgentCommissionsV2Page'));
  });

  test('D ne modifie aucun moteur métier critique', () {
    final Directory feature = Directory('lib/features/commissions');
    final String all = feature
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .map((File file) => file.readAsStringSync())
        .join('\n');

    expect(all, isNot(contains("collection('orders')")));
    expect(all, isNot(contains("collection('agentProfiles')")));
    expect(all, isNot(contains("collection('networkTransactions')")));
    expect(all, isNot(contains('runTransaction')));
    expect(all, isNot(contains('WriteBatch')));
    expect(all, isNot(contains('.set(')));
    expect(all, isNot(contains('.update(')));
    expect(all, isNot(contains('.delete(')));
  });
}
