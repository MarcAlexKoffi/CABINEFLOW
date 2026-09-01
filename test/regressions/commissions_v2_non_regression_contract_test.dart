import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('D reste une couche de lecture des collections Phase 12', () {
    final String repository = _read(
      'lib/features/commissions/data/repositories/firestore_commission_v2_repository.dart',
    );

    expect(repository, contains("collection('commissions')"));
    expect(repository, contains("collection('commissionAccounts')"));
    expect(repository, contains("collection('commissionPayouts')"));
    expect(repository, contains("where('agentId', isEqualTo: agentId)"));

    expect(repository, isNot(contains('.set(')));
    expect(repository, isNot(contains('.update(')));
    expect(repository, isNot(contains('.delete(')));
    expect(repository, isNot(contains('runTransaction')));
    expect(repository, isNot(contains('WriteBatch')));
    expect(repository, isNot(contains("collection('orders')")));
    expect(repository, isNot(contains("collection('agentProfiles')")));
  });

  test('D ne remplace pas les règles Phase 12 existantes', () {
    final String rules = _read('firestore.rules');

    expect(rules, contains('match /commissions/'));
    expect(rules, contains('match /commissionAccounts/'));
    expect(rules, contains('match /commissionPayouts/'));
    expect(rules, contains('commissionAmount'));
    expect(rules, contains('earnedTotal'));
    expect(rules, contains('paidTotal'));
  });

  test('les points d’accès Agent/Admin vers D sont présents', () {
    final String activity = _read(
      'lib/features/agents/presentation/pages/agent_activity_v2_dashboard_page.dart',
    );
    final String adminProfile = _read(
      'lib/features/agents/presentation/pages/admin_agent_profile_activity_page.dart',
    );
    final String personalProfile = _read(
      'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
    );

    expect(activity, contains('AdminAgentCommissionsV2Page'));
    expect(activity, contains('AgentCommissionsV2Page'));
    expect(adminProfile, contains('AdminCommissionsV2Page'));
    expect(adminProfile, contains('AdminAgentCommissionsV2Page'));
    expect(personalProfile, contains('AgentCommissionsV2Page'));
  });
}

String _read(String path) {
  final File file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Fichier manquant: $path');
  return file.readAsStringSync();
}
