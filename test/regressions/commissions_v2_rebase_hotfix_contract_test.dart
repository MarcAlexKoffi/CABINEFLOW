import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'D preserve le hotfix profil B2 et l accès commissions depuis Accueil',
    () {
      final String profile = File(
        'lib/app/modules/profile/views/agent_personal_profile_page.dart',
      ).readAsStringSync();
      final String home = File(
        'lib/app/modules/agent_ops/views/agent_home_page.dart',
      ).readAsStringSync();
      final String shell = File(
        'lib/app/modules/home/views/main_shell_page.dart',
      ).readAsStringSync();

      expect(profile, contains('_hydrateFromSignedInUser();'));
      expect(profile, contains('_mediaWarning'));
      expect(
        profile,
        contains('Certains médias Supabase sont temporairement indisponibles'),
      );
      expect(profile, isNot(contains('AgentCommissionsV2Page')));
      expect(home, contains("title: 'Mes commissions'"));
      expect(home, contains('onOpenCommissions'));
      expect(shell, contains('AgentCommissionsPage'));
    },
  );

  test('D preserve la résilience Activité V2', () {
    final String source = File(
      'lib/app/modules/agent_ops/views/agent_activity_v2_dashboard_page.dart',
    ).readAsStringSync();

    expect(source, contains('hasUnavailableSources'));
    expect(source, contains('AgentActivityV2Sources.movements'));
    expect(source, contains('_UnavailableCard'));
    expect(source, contains('Historique complet & statistiques'));
    expect(source, contains('AgentCommissionsV2Page'));
    expect(source, contains('AdminAgentCommissionsV2Page'));
  });

  test('D conserve l encapsulation du moteur métier critique', () {
    final Directory presentation = Directory('lib/app/modules/commissions');
    final String uiAndDomain =
        <Directory>[
              presentation,
              Directory('lib/app/domain/entities/commissions'),
              Directory('lib/app/domain/policies/commissions'),
            ]
            .expand(
              (Directory directory) => directory.listSync(recursive: true),
            )
            .whereType<File>()
            .where((File file) => file.path.endsWith('.dart'))
            .map((File file) => file.readAsStringSync())
            .join('\n');
    final String contracts =
        <String>[
              'agent_commission_summary_repository.dart',
              'commission_repository.dart',
              'commission_v2_repository.dart',
            ]
            .map(
              (String name) =>
                  File('lib/app/domain/repositories/$name').readAsStringSync(),
            )
            .join('\n');

    // Les pages et le domaine ne doivent jamais écrire directement dans
    // Firestore : les écritures restent encapsulées dans le repository.
    final String protectedSources = '$uiAndDomain\n$contracts';
    expect(protectedSources, isNot(contains('runTransaction')));
    expect(protectedSources, isNot(contains('WriteBatch')));
    expect(protectedSources, isNot(contains('.set(')));
    expect(protectedSources, isNot(contains('.update(')));
    expect(protectedSources, isNot(contains('.delete(')));

    final String repository = File(
      'lib/app/data/repositories/firestore_commission_repository.dart',
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
