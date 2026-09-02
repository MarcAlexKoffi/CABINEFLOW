import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'profil Agent utilise Supabase et conserve les règles Firestore legacy',
    () {
      final String rules = File('firestore.rules').readAsStringSync();
      final String profile = File(
        'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
      ).readAsStringSync();
      final String repository = File(
        'lib/features/agents/data/repositories/'
        'supabase_agent_personal_profile_repository.dart',
      ).readAsStringSync();

      expect(profile, contains('SupabaseAgentPersonalProfileRepository'));
      expect(profile, contains('avatarPresent'));
      expect(profile, contains('identityPresent'));
      expect(repository, contains("tableName = 'agent_personal_profiles'"));
      expect(repository, contains("bucketName = 'agent-personal'"));
      // Les contrats Firestore restent présents tant que la migration complète
      // n'est pas terminée.
      expect(
        rules,
        contains('match /agentPersonalMedia/{agentId}/items/{kind}'),
      );
    },
  );

  test('refus Agent ne retombe plus dans le lien generique circulaire', () {
    final String rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('function isValidAgentAssignmentRefusedEvent()'));
    expect(
      rules,
      contains(
        "request.resource.data.type == 'ASSIGNMENT_REFUSED'\n"
        '        && isValidAgentAssignmentRefusedEvent()',
      ),
    );
    expect(rules, contains("'ASSIGNED',\n          'ASSIGNMENT_REFUSED'"));
  });

  test(
    'signalements et fournisseurs conservent les correctifs fonctionnels',
    () {
      final String rules = File('firestore.rules').readAsStringSync();

      expect(rules, contains("'in_progress'"));
      expect(rules, contains('function isValidFinanceSupplierDelete'));
      expect(
        rules,
        contains('allow delete: if isValidFinanceSupplierDelete(supplierId);'),
      );
    },
  );

  test('Accueil et Profil exposent le suivi comme navigation explicite', () {
    final String home = File(
      'lib/features/agents/presentation/pages/agent_home_page.dart',
    ).readAsStringSync();
    final String profile = File(
      'lib/features/agents/presentation/pages/agent_activity_page.dart',
    ).readAsStringSync();
    final String shell = File(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    ).readAsStringSync();

    expect(home, contains("const IzyTelSectionHeader(title: 'Mon suivi')"));
    expect(home, contains("title: 'Mon activité détaillée'"));
    expect(home, contains("title: 'Mes commissions'"));
    expect(profile, contains("const _SectionLabel('Mon suivi')"));
    expect(profile, contains("title: 'Mon activité détaillée'"));
    expect(profile, contains("title: 'Mes commissions'"));
    expect(shell, contains('AgentCommissionsPage'));
    expect(shell, isNot(contains('builder: (_) => AgentCommissionsV2Page')));
  });
}
