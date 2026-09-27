import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('BO-6 - Controle et Pilotage', () {
    test('les trois destinations BO-6 sont routees vers une vraie page', () {
      final String shell = _read('lib/backoffice/presentation/pages/backoffice_shell_page.dart');
      final String page = _read('lib/backoffice/presentation/pages/control/backoffice_control_page.dart');
      expect(shell, contains('BackofficeControlModule.activity'));
      expect(shell, contains('BackofficeControlModule.audit'));
      expect(shell, contains('BackofficeControlModule.statistics'));
      expect(shell, contains('BackofficeControlPage('));
      expect(page, contains('Journal d’activité'));
      expect(page, contains('Audit / historique'));
      expect(page, contains('Statistiques opérationnelles'));
    });

    test('les dix modules Finances sont reserves a l Administrateur', () {
      final String permissions = _read('lib/features/auth/domain/permissions/user_permissions.dart');
      final String shell = _read('lib/backoffice/presentation/pages/backoffice_shell_page.dart');
      expect(permissions, contains('static const UserPermissions manager'));
      expect(permissions, contains('canViewOperationalFinances: false'));
      expect(shell, contains('case BackofficeDestination.closings:'));
      expect(shell, contains('return user.role == UserRole.administrator;'));
      expect(shell, contains('case BackofficeDestination.audit:'));
    });

    test('le snapshot Supabase limite le Manager a son territoire et l audit a Admin', () {
      final String migration = _read('supabase/migrations/20260915233200_bo6_control_pilotage.sql');
      expect(migration, contains('izytel_bo6_control_snapshot'));
      expect(migration, contains("z.manager_id = v_uid"));
      expect(migration, contains("z.id = any(coalesce(c.zone_ids"));
      expect(migration, contains("v_admin := v_role = 'admin'"));
      expect(migration, contains("'audit_allowed',v_admin"));
      expect(migration, contains("'manager_territory'"));
      expect(migration, contains('security definer'));
      expect(migration, contains("set search_path = ''"));
    });

    test('l application Manager expose le pilotage mais pas les finances BO-5', () {
      final String more = _read('lib/features/more/presentation/pages/more_page.dart');
      final String page = _read('lib/features/control/presentation/pages/manager_pilotage_page.dart');
      final String permissions = _read('lib/features/auth/domain/permissions/user_permissions.dart');
      expect(more, contains('Pilotage opérationnel'));
      expect(more, contains('ManagerPilotagePage('));
      final int moreManagerStart = more.indexOf('Widget _buildManager');
      final int moreManagerEnd = more.indexOf('void _historyUnavailable', moreManagerStart);
      final String managerMoreBlock = more.substring(moreManagerStart, moreManagerEnd);
      expect(managerMoreBlock, isNot(contains('Finances opérationnelles')));
      expect(managerMoreBlock, isNot(contains('FinancesPage(')));
      expect(page, contains('Mon périmètre'));
      expect(page, contains('Les finances sensibles restent réservées à l’Administrateur'));
      final int managerStart = permissions.indexOf('static const UserPermissions manager');
      final int legacyStart = permissions.indexOf('static const UserPermissions legacyOperator');
      final String managerBlock = permissions.substring(managerStart, legacyStart);
      expect(managerBlock, contains('canViewOperationalFinances: false'));
    });

    test('le dashboard Manager ne met plus en avant les encaissements', () {
      final String dashboard = _read('lib/features/dashboard/presentation/pages/dashboard_page.dart');
      expect(dashboard, contains('managerMode: widget.user.isManager'));
      expect(dashboard, contains("managerMode ? 'Supervision du jour' : 'Encaissements aujourd’hui'"));
      expect(dashboard, contains('managerMode ? Symbols.monitoring_rounded'));
    });


    test('le correctif analyse BO-6 garde le switch exhaustif et l icone Manager non const', () {
      final String shell = _read('lib/backoffice/presentation/pages/backoffice_shell_page.dart');
      final String dashboard = _read('lib/features/dashboard/presentation/pages/dashboard_page.dart');
      expect(shell, isNot(contains('_BackofficeModulePlaceholder')));
      expect(shell, isNot(contains('String get milestone')));
      expect(shell, isNot(contains('izytel_design_tokens.dart')));
      expect(
        dashboard,
        contains('managerMode ? Symbols.monitoring_rounded : Symbols.account_balance_wallet_rounded'),
      );
      expect(dashboard, isNot(contains('child: const Icon(\n                  managerMode ? Symbols.monitoring_rounded')));
    });
  });
}
