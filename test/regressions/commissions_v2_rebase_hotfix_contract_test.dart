import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('D preserve le hotfix profil B2 et l accès commissions depuis Accueil', () {
    final String profile = File(
      'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
    ).readAsStringSync();
    final String home = File(
      'lib/features/agents/presentation/pages/agent_home_page.dart',
    ).readAsStringSync();

    expect(profile, contains('_hydrateFromSignedInUser();'));
    expect(profile, contains('_mediaWarning'));
    expect(profile, contains('Certains médias du profil sont temporairement indisponibles'));
    expect(profile, isNot(contains('AgentCommissionsV2Page')));
    expect(home, contains('AgentCommissionsV2Page'));
    expect(home, contains("title: 'Mes commissions'"));
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

  test('D conserve l encapsulation du moteur métier critique', () {
    final Directory presentation = Directory(
      'lib/features/commissions/presentation',
    );
    final Directory domain = Directory('lib/features/commissions/domain');
    final String uiAndDomain = <Directory>[presentation, domain]
        .expand((Directory directory) => directory.listSync(recursive: true))
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .map((File file) => file.readAsStringSync())
        .join('\n');

    // Les pages et le domaine ne doivent jamais écrire directement dans
    // Firestore : les écritures restent encapsulées dans le repository.
    expect(uiAndDomain, isNot(contains('runTransaction')));
    expect(uiAndDomain, isNot(contains('WriteBatch')));
    expect(uiAndDomain, isNot(contains('.set(')));
    expect(uiAndDomain, isNot(contains('.update(')));
    expect(uiAndDomain, isNot(contains('.delete(')));

    final String repository = File(
      'lib/features/commissions/data/repositories/firestore_commission_repository.dart',
    ).readAsStringSync();

    // Le paiement réel d'une commission est volontairement transactionnel.
    expect(repository, contains('Future<void> recordPayout'));
    expect(repository, contains('_firestore.runTransaction<void>'));
    expect(repository, contains('transaction.set(payoutRef'));
    expect(repository, contains('transaction.update(accountRef'));
    expect(repository, contains("_firestore.collection('commissionPayouts')"));
    expect(repository, contains("_firestore.collection('commissionAccounts')"));
  });
}
