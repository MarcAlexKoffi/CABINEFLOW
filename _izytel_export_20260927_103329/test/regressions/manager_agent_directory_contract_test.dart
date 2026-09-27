import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();
  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  test('navigation Manager expose Agents sans remplacer Finances Admin', () {
    final String shell = compact(
      read('lib/features/navigation/presentation/pages/main_shell_page.dart'),
    );
    final String navigation = read(
      'lib/features/dashboard/presentation/widgets/dashboard_widgets.dart',
    );

    expect(shell, contains('widget.user.isManager ? AgentManagementPage('));
    expect(shell, contains(': FinancesPage('));
    expect(shell, contains('managerMode: widget.user.isManager'));
    expect(navigation, contains("label: 'Agents'"));
    expect(navigation, contains("label: 'Finances'"));
    expect(navigation, contains('_managerItems'));
    expect(navigation, contains('_adminItems'));
  });

  test('annuaire Manager est consultation uniquement', () {
    final String page = read(
      'lib/features/agents/presentation/pages/agent_management_page.dart',
    );

    expect(page, contains('widget.user.permissions.canManageAgents'));
    expect(
      page,
      contains('readOnly: !widget.user.permissions.canManageAgents'),
    );
    expect(page, contains('if (canManageAgents) ...['));
    expect(page, contains("label: const Text('Ajouter un agent')"));
  });

  test('fiche Agent bloque toutes les commandes Admin en lecture seule', () {
    final String detail = read(
      'lib/features/agents/presentation/pages/agent_detail_page.dart',
    );

    expect(detail, contains('this.readOnly = false'));
    expect(detail, contains("widget.readOnly ? 'Supervision Agent' : 'Profil Agent'"));
    expect(detail, contains('readOnly: widget.readOnly'));
    expect(detail, contains('onSelected: widget.readOnly'));
    expect(detail, contains('onChanged: widget.readOnly'));
    expect(detail, contains('if (!widget.readOnly) ...['));
  });

  test('M4 ne demande aucun nouveau droit Manager sensible', () {
    final String permissions = read(
      'lib/features/auth/domain/permissions/user_permissions.dart',
    );
    final String manager = permissions.substring(
      permissions.indexOf('static const UserPermissions manager'),
      permissions.indexOf('static const UserPermissions legacyOperator'),
    );

    expect(manager, contains('canViewAgentDirectory: true'));
    expect(manager, contains('canManageAgents: false'));
    expect(manager, contains('canManageFinanceSettings: false'));
    expect(manager, contains('canManageRefunds: false'));
    expect(manager, contains('canManageOffers: false'));
  });
}
