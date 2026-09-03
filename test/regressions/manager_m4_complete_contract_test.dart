import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();
  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  test('M4 couvre Agents, assistance, signalements et finances Manager', () {
    final String more = compact(
      read('lib/features/more/presentation/pages/more_page.dart'),
    );
    final String permissions = read(
      'lib/features/auth/domain/permissions/user_permissions.dart',
    );
    final int start = permissions.indexOf(
      'static const UserPermissions manager',
    );
    final int end = permissions.indexOf(
      'static const UserPermissions legacyOperator',
      start,
    );
    final String manager = permissions.substring(start, end);

    expect(more, contains("title: 'Demandes clients'"));
    expect(more, contains("title: 'Affectations des commandes'"));
    expect(more, contains("title: 'Agents'"));
    expect(more, contains("title: 'Signalements agents'"));
    expect(more, contains("title: 'Finances opérationnelles'"));

    expect(manager, contains('canAssignOrders: true'));
    expect(manager, contains('canConfirmPayments: true'));
    expect(manager, contains('canViewSupportRequests: true'));
    expect(manager, contains('canResolveAgentIssues: true'));
    expect(manager, contains('canViewOperationalFinances: true'));
    expect(manager, contains('canManageAgents: false'));
    expect(manager, contains('canManageOffers: false'));
    expect(manager, contains('canManageRefunds: false'));
    expect(manager, contains('canManageFinanceSettings: false'));
  });

  test('Admin garde ses fonctions sensibles hors du bloc Manager', () {
    final String more = read(
      'lib/features/more/presentation/pages/more_page.dart',
    );
    final int start = more.indexOf('Widget _buildManager');
    final int end = more.indexOf('void _historyUnavailable', start);
    final String managerBlock = more.substring(start, end);

    expect(managerBlock, isNot(contains('OfferManagementPage(')));
    expect(managerBlock, isNot(contains('FailedOrdersPage(')));
    expect(managerBlock, isNot(contains('FirestoreRefundRepository')));
    expect(managerBlock, contains('FakeRefundRepository()'));
  });

  test('M4 ne depend d aucune nouvelle rule Firestore', () {
    // Le projet peut naturellement contenir son firestore.rules historique.
    // M4 est valide par ses sources Flutter/Supabase, sans scanner `build/` ni
    // deduire l'origine d'un fichier a partir de son nom local.
    final String shell = read(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );
    final String finance = read(
      'lib/features/finances/presentation/pages/finances_page.dart',
    );

    expect(shell, isNot(contains('firebase deploy --only firestore:rules')));
    expect(finance, isNot(contains('firebase deploy --only firestore:rules')));
    expect(File('lib/firestore.rules').existsSync(), isFalse);
  });
}
