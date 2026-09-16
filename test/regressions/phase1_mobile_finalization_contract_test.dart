import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();
  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  test('Admin mobile reste fonctionnel tant que le back-office Web ne le remplace pas', () {
    final String shell = compact(
      read('lib/features/navigation/presentation/pages/main_shell_page.dart'),
    );
    final String more = compact(
      read('lib/features/more/presentation/pages/more_page.dart'),
    );
    final String permissions = compact(
      read('lib/features/auth/domain/permissions/user_permissions.dart'),
    );

    expect(shell, contains('widget.user.role == UserRole.administrator'));
    expect(shell, contains('FinancesPage('));
    expect(shell, contains('MorePage('));
    expect(more, contains("title: 'Administration'"));
    expect(more, contains("title: 'Offres'"));
    expect(more, contains("title: 'Agents et zones'"));
    expect(more, contains("title: 'Signalements agents'"));
    expect(permissions, contains('static const UserPermissions administrator'));
    expect(permissions, contains('canManageAgents: true'));
    expect(permissions, contains('canManageOffers: true'));
    expect(permissions, contains('canManageRefunds: true'));
  });

  test('Agent garde ses raccourcis operationnels officiels sans libelle V2', () {
    final String home = read(
      'lib/features/agents/presentation/pages/agent_home_page.dart',
    );
    final String profile = read(
      'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
    );

    expect(home, contains("title: 'Mon activité détaillée'"));
    expect(home, contains("title: 'Mes commissions'"));
    expect(home, contains("title: 'Mes signalements'"));
    expect(home, contains("label: const Text('Historique')"));
    expect(profile, isNot(contains('Mes commissions V2')));
    expect(profile, isNot(contains('activité détaillée V2')));
  });

  test('Manager garde les fonctions operationnelles sans pouvoirs Admin', () {
    final String more = compact(
      read('lib/features/more/presentation/pages/more_page.dart'),
    );
    final String permissions = read(
      'lib/features/auth/domain/permissions/user_permissions.dart',
    );
    final int start = permissions.indexOf('static const UserPermissions manager');
    final int end = permissions.indexOf('static const UserPermissions legacyOperator', start);
    final String manager = permissions.substring(start, end);

    expect(more, contains("title: 'Demandes clients'"));
    expect(more, contains("title: 'Affectations des commandes'"));
    expect(more, contains("title: 'Agents'"));
    expect(more, contains("title: 'Signalements agents'"));
    expect(more, contains("title: 'Pilotage opérationnel'"));
    expect(manager, contains('canViewOperationalFinances: false'));
    expect(manager, contains('canAssignOrders: true'));
    expect(manager, contains('canConfirmPayments: true'));
    expect(manager, contains('canResolveAgentIssues: true'));
    expect(manager, contains('canManageOffers: false'));
    expect(manager, contains('canManageRefunds: false'));
  });

  test('les flux Finance Supabase survivent aux erreurs transitoires', () {
    final String repository = read(
      'lib/features/finances/data/repositories/supabase_phase5_finance_repository.dart',
    );
    final int start = repository.indexOf('Stream<List<T>> _poll<T>');
    final int end = repository.indexOf('CommissionEntry? _commission', start);
    final String poll = repository.substring(start, end);

    expect(poll, contains('yield lastSuccessful ?? <T>[];'));
    expect(poll, isNot(contains('rethrow;')));
  });

  test('un ancien profil Agent sans nom ne bloque plus le backfill des capacites', () {
    final String sync = read(
      'lib/features/finances/data/services/phase5_consolidated_synchronizer.dart',
    );

    expect(sync, contains("'agent_name': _legacyAgentName("));
    expect(sync, contains('[Phase5][Backfill][capacity-name-fallback]'));
    expect(sync, contains('String _requiredName(Object? value, String id)'));
  });

  test('le bloc Notifications valide reste branche', () {
    final String shell = read(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );
    final String bootstrap = read(
      'lib/core/notifications/firebase_messaging_bootstrap.dart',
    );

    expect(shell, contains('IzyTelNotificationDeviceRegistry.start'));
    expect(shell, contains('FirebaseMessagingBootstrap.openedPayloads'));
    expect(bootstrap, contains('[FCM][token]'));
    expect(bootstrap, contains('FirebaseMessaging.onBackgroundMessage'));
  });
}
