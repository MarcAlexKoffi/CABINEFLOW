import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('le refus Agent ne recree pas un cycle getAfter', () {
    final String rules = _read('firestore.rules');

    expect(rules, contains('function isValidAgentAssignmentRefusedEvent()'));
    expect(rules, contains("request.resource.data.type == 'ASSIGNMENT_REFUSED'"));
    expect(rules, contains('let orderBefore = get('));
    expect(rules, contains("hasMatchingOrderEvent(orderId, 'ASSIGNMENT_REFUSED')"));
  });

  test('le suivi des signalements accepte en cours et trace la cloture', () {
    final String rules = _read('firestore.rules');
    final String page = _read(
      'lib/features/agents/presentation/pages/agent_issues_page.dart',
    );

    expect(rules, contains("'in_progress'"));
    expect(rules, contains('closesIssue'));
    expect(rules, contains('request.resource.data.resolvedAt == request.time'));
    expect(rules, contains('request.resource.data.resolvedBy is string'));
    expect(page, contains('Rechercher un signalement'));
    expect(page, contains('_AgentIssueDetailSheet'));
    expect(page, contains("label: resolved ? 'R\u00e9solu par' : 'Class\u00e9 par'"));
  });

  test('la photo Agent est autorisee en Blob Firestore', () {
    final String rules = _read('firestore.rules');
    final String profile = _read(
      'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
    );

    expect(rules, contains('match /agentPersonalMedia/{agentId}/items/{kind}'));
    expect(rules, contains('request.resource.data.contentBytes is bytes'));
    expect(profile, contains("'hasAvatarMedia': avatarPresent"));
    expect(profile, contains("'hasIdentityDocumentMedia': identityPresent"));
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
    expect(home, contains("title: 'Mon activit\u00e9 d\u00e9taill\u00e9e'"));
    expect(home, contains("title: 'Mes commissions'"));
    expect(profile, isNot(contains('Mes commissions V2')));
    expect(profile, isNot(contains('Voir mon activit\u00e9 d\u00e9taill\u00e9e')));
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

    expect(cards, contains("'Non affect\u00e9e'"));
    expect(cards, contains("'Affectation manuelle requise'"));
    expect(page, contains('unassignedPaidCount'));
    expect(dashboard, contains('unassignedOrders'));
    expect(dashboard, contains('sans agent \u00e0 v\u00e9rifier'));
  });

  test('le profil Admin Agent ne contient plus la bulle superposee', () {
    final String page = _read(
      'lib/features/agents/presentation/pages/agent_detail_page.dart',
    );

    expect(page, isNot(contains('floatingActionButton:')));
    expect(page, contains('Identit\u00e9 et activit\u00e9 d\u00e9taill\u00e9e'));
    expect(page, isNot(contains('Identit\u00c3\u00a9')));
  });

  test('les fournisseurs peuvent etre modifies et supprimes sans historique', () {
    final String interface = _read(
      'lib/features/finances/domain/repositories/finance_operations_repository.dart',
    );
    final String firestoreRepository = _read(
      'lib/features/finances/data/repositories/'
      'firestore_finance_operations_repository.dart',
    );
    final String page = _read(
      'lib/features/finances/presentation/pages/supplier_finance_page.dart',
    );
    final String rules = _read('firestore.rules');

    expect(interface, contains('Future<void> updateSupplier'));
    expect(interface, contains('Future<void> deleteSupplier'));
    expect(firestoreRepository, contains('Future<void> updateSupplier'));
    expect(firestoreRepository, contains('Future<void> deleteSupplier'));
    expect(page, contains("value: 'edit'"));
    expect(page, contains("value: 'delete'"));
    expect(rules, contains('isValidFinanceSupplierDelete(supplierId)'));
  });
}
