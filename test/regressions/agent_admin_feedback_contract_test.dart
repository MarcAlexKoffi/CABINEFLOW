import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('le refus Agent passe par Supabase Phase 4 sans cycle Firestore', () {
    final String hybrid = _read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final String phase4 = _read(
      'lib/features/orders/data/repositories/'
      'supabase_phase4_assignment_repository.dart',
    );

    expect(hybrid, contains('Future<QueueOrder> refuseAgentAssignment'));
    expect(hybrid, contains('_phase4.refuse(orderId: orderId'));
    expect(phase4, contains("'phase4_agent_action'"));
    expect(phase4, contains("action: 'refuse'"));
  });

  test('le suivi des signalements Supabase accepte en cours et trace la cloture', () {
    final String repository = _read(
      'lib/features/agents/data/repositories/'
      'supabase_agent_issue_repository.dart',
    );
    final String page = _read(
      'lib/features/agents/presentation/pages/agent_issues_page.dart',
    );

    expect(repository, contains("'in_progress'"));
    expect(repository, contains('closesIssue'));
    expect(repository, contains("'resolved_by': closesIssue"));
    expect(page, contains('Rechercher un signalement'));
    expect(page, contains('_AgentIssueDetailSheet'));
    expect(
      page,
      contains("label: resolved ? 'Résolu par' : 'Classé par'"),
    );
  });

  test('la photo Agent est migrée vers Supabase Storage', () {
    final String profile = _read(
      'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
    );
    final String repository = _read(
      'lib/features/agents/data/repositories/'
      'supabase_agent_personal_profile_repository.dart',
    );

    expect(profile, contains('SupabaseAgentPersonalProfileRepository'));
    expect(profile, isNot(contains('WriteBatch')));
    expect(repository, contains("bucketName = 'agent-personal'"));
    expect(repository, contains('.uploadBinary('));
  });

  test('l espace Agent possede un accueil et les raccourcis officiels', () {
    final String shell = _read(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );
    final String home = _read(
      'lib/features/agents/presentation/pages/agent_home_page.dart',
    );
    final String profile = _read(
      'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
    );

    expect(shell, contains('AgentHomePage('));
    expect(shell, contains("label: 'Accueil'"));
    expect(home, contains("title: 'Mon activité détaillée'"));
    expect(home, contains("title: 'Mes commissions'"));
    expect(profile, isNot(contains('Mes commissions V2')));
    expect(
      profile,
      isNot(contains('Voir mon activité détaillée')),
    );
  });

  test('les commandes sans Agent sont visibles cote Admin', () {
    final String cards = _read(
      'lib/features/orders/presentation/widgets/orders_widgets.dart',
    );
    final String page = _read(
      'lib/features/orders/presentation/pages/orders_page.dart',
    );
    final String dashboard = _read(
      'lib/features/dashboard/presentation/pages/dashboard_page.dart',
    );

    expect(cards, contains("'Non affectée'"));
    expect(cards, contains("'Affectation manuelle requise'"));
    // La page Commandes n'affiche plus de grosse bulle permanente pour les
    // commandes sans Agent. L'etat reste porte par chaque carte/action.
    expect(page, contains('order.manualAssignmentRequired'));
    expect(page, isNot(contains('unassignedPaidCount')));
    expect(dashboard, contains('unassignedOrders'));
    expect(dashboard, contains('sans agent à vérifier'));
  });

  test('le profil Admin Agent ne contient plus la bulle superposee', () {
    final String page = _read(
      'lib/features/agents/presentation/pages/agent_detail_page.dart',
    );

    expect(page, isNot(contains('floatingActionButton:')));
    expect(
      page,
      contains('Identité et activité détaillée'),
    );
    expect(page, isNot(contains('IdentitÃ©')));
  });

  test('les fournisseurs sont modifies et supprimes via Supabase', () {
    final String interface = _read(
      'lib/features/finances/domain/repositories/finance_operations_repository.dart',
    );
    final String hybridRepository = _read(
      'lib/features/finances/data/repositories/'
      'hybrid_finance_operations_repository.dart',
    );
    final String supplierRegistry = _read(
      'lib/features/finances/data/repositories/'
      'supabase_supplier_registry_repository.dart',
    );
    final String page = _read(
      'lib/features/finances/presentation/pages/supplier_finance_page.dart',
    );

    expect(interface, contains('Future<void> updateSupplier'));
    expect(interface, contains('Future<void> deleteSupplier'));
    expect(hybridRepository, contains('Future<void> updateSupplier'));
    expect(hybridRepository, contains('Future<void> deleteSupplier'));
    expect(hybridRepository, contains('_supplierRegistry.softDeleteSupplier('));
    expect(supplierRegistry, contains("tableName = 'finance_suppliers'"));
    expect(supplierRegistry, contains('Future<void> softDeleteSupplier'));
    expect(page, contains("value: 'edit'"));
    expect(page, contains("value: 'delete'"));
  });
}
