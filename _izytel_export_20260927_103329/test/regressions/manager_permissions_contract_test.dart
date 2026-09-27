import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();
  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  test('Auth traduit supervisor Firestore en Manager Flutter', () {
    final String auth = compact(
      read('lib/features/auth/data/repositories/firebase_auth_repository.dart'),
    );
    expect(auth, contains("case 'manager': return UserRole.manager;"));
    expect(auth, contains("case 'supervisor':"));
    expect(auth, contains('return UserRole.manager;'));
  });

  test('permissions Manager sont centralisees hors des pages', () {
    final String permissions = read(
      'lib/features/auth/domain/permissions/user_permissions.dart',
    );
    expect(permissions, contains('class UserPermissions'));
    expect(permissions, contains('firestoreCompatibilityRole'));
    expect(permissions, contains("return 'supervisor';"));
    expect(permissions, contains('supabaseStaffRole'));
    expect(permissions, contains("return 'manager';"));
  });

  test('Manager affecte via la matrice sans reprendre le flux operateur', () {
    final String orders = read(
      'lib/features/orders/presentation/pages/orders_page.dart',
    );
    expect(orders, contains('widget.user.permissions.canAssignOrders'));
  });

  test('Plus Manager ne publie aucune fonction Admin sensible', () {
    final String more = read('lib/features/more/presentation/pages/more_page.dart');
    final int start = more.indexOf('Widget _buildManager');
    final int end = more.indexOf('void _historyUnavailable', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final String managerBlock = more.substring(start, end);

    expect(managerBlock, contains('Affectations des commandes'));
    expect(managerBlock, contains('Signalements agents'));
    expect(managerBlock, contains('AgentManagementPage'));
    expect(managerBlock, contains("label: 'Agents'"));
    expect(managerBlock, isNot(contains('OfferManagementPage')));
    expect(managerBlock, contains('SupportRequestCenterPage'));
    expect(managerBlock, contains('FakeRefundRepository()'));
    expect(managerBlock, isNot(contains('FailedOrdersPage')));
    expect(managerBlock, isNot(contains('FirestoreRefundRepository')));
  });

  test('Dashboard Manager ne lit pas refunds Firestore en arriere plan', () {
    final String dashboard = compact(
      read('lib/features/dashboard/presentation/pages/dashboard_page.dart'),
    );
    expect(
      dashboard,
      contains('if (widget.user.permissions.canManageRefunds) {'),
    );
  });

  test('Manager utilise Agents a la place des Finances Admin', () {
    final String shell = compact(
      read('lib/features/navigation/presentation/pages/main_shell_page.dart'),
    );
    expect(shell, contains('widget.user.isManager ? AgentManagementPage('));
    expect(shell, contains(': FinancesPage('));
    expect(shell, contains('managerMode: widget.user.isManager'));
    // Le backfill consolide reste explicitement Admin et ne depend pas de la
    // matrice Manager.
    expect(shell, contains('widget.user.role == UserRole.administrator'));
  });
}
