import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'profil Agent utilise Supabase et conserve seulement le profil Firestore legacy',
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
      expect(repository, contains('avatarMaxBytes = 250000'));
      expect(repository, contains('identityMaxBytes = 850000'));
      // Firestore ne conserve que le contrat de profil legacy. Les blobs sont
      // désormais stockés dans le bucket privé Supabase.
      expect(rules, contains('match /agentPersonalProfiles/{agentId}'));
    },
  );

  test('refus Agent utilise Phase 4 et ne retombe pas dans le lien Firestore', () {
    final String hybrid = File(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    ).readAsStringSync();
    final String phase4 = File(
      'lib/features/orders/data/repositories/'
      'supabase_phase4_assignment_repository.dart',
    ).readAsStringSync();

    expect(hybrid, contains('Future<QueueOrder> refuseAgentAssignment'));
    expect(hybrid, contains('_phase4.refuse(orderId: orderId'));
    expect(phase4, contains("'phase4_agent_action'"));
    expect(phase4, contains("action: 'refuse'"));
  });

  test(
    'signalements et fournisseurs conservent les correctifs Supabase',
    () {
      final String issues = File(
        'lib/features/agents/data/repositories/'
        'supabase_agent_issue_repository.dart',
      ).readAsStringSync();
      final String hybridFinance = File(
        'lib/features/finances/data/repositories/'
        'hybrid_finance_operations_repository.dart',
      ).readAsStringSync();
      final String suppliers = File(
        'lib/features/finances/data/repositories/'
        'supabase_supplier_registry_repository.dart',
      ).readAsStringSync();

      expect(issues, contains("'in_progress'"));
      expect(issues, contains('closesIssue'));
      expect(issues, contains("'resolved_by': closesIssue"));
      expect(hybridFinance, contains('_supplierRegistry.softDeleteSupplier('));
      expect(suppliers, contains('Future<void> softDeleteSupplier'));
      expect(suppliers, contains("tableName = 'finance_suppliers'"));
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
