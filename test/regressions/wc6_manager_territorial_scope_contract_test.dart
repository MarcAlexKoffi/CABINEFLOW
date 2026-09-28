import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC6 - Manager territorial strict', () {
    test('le backend zone les commandes agents support et remboursements', () {
      final String sql = File(
        'supabase/migrations/20260927150000_wc6_manager_territorial_scope.sql',
      ).readAsStringSync();

      expect(sql, contains('izytel_wc6_visible_legacy_order_ids'));
      expect(sql, contains('phase5 capacity territorial read'));
      expect(sql, contains('support customer or territorial staff read'));
      expect(sql, contains('refund territorial staff read'));
      expect(sql, contains('MANAGER_ZONE_REQUIRED'));
      expect(sql, contains("notification_channel = 'izytel'"));
      expect(sql, contains('wc6_support_fill_zone'));
      expect(sql, contains('wc6_refund_fill_zone'));
    });

    test('les commandes Manager ferment toute fuite Firestore globale', () {
      final String source = File(
        'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
      ).readAsStringSync();

      expect(source, contains('AppUser? viewer'));
      expect(source, contains('bool get _isManager'));
      expect(source, contains('_filterLegacyOrdersToManagerScope'));
      expect(source, contains('fetchVisibleLegacyOrderIds'));
      expect(source, contains('if (_isManager) return;'));
      expect(source, contains('_canonicalOrders'));
    });

    test('dashboard et annuaire Agent connaissent le viewer Manager', () {
      final String dashboard = File(
        'lib/features/dashboard/data/repositories/hybrid_dashboard_repository.dart',
      ).readAsStringSync();
      final String agents = File(
        'lib/features/agents/data/repositories/firestore_agent_repository.dart',
      ).readAsStringSync();
      final String shell = File(
        'lib/features/navigation/presentation/pages/main_shell_page.dart',
      ).readAsStringSync();

      expect(dashboard, contains('AppUser? viewer'));
      expect(dashboard, contains('if (!_isManager)'));
      expect(agents, contains('operationsByAgent.containsKey(doc.id)'));
      expect(shell, contains('widget.user.role == UserRole.administrator'));
    });

    test('le Manager peut traiter Support et echecs sans devenir Admin finance', () {
      final String permissions = File(
        'lib/features/auth/domain/permissions/user_permissions.dart',
      ).readAsStringSync();
      final RegExp managerBlock = RegExp(
        r'static const UserPermissions manager = UserPermissions\(([\s\S]*?)\n  \);',
      );
      final Match? match = managerBlock.firstMatch(permissions);
      expect(match, isNotNull);
      final String block = match!.group(1)!;
      expect(block, contains('canProcessSupportRequests: true'));
      expect(block, contains('canManageFailedOrders: true'));
      expect(block, contains('canManageRefunds: false'));
      expect(block, contains('canManageFinanceSettings: false'));
    });

    test('les nouveaux Agents sont administrables meme avant profil operationnel', () {
      final String source = File(
        'lib/backoffice/presentation/pages/team/backoffice_agents_page.dart',
      ).readAsStringSync();
      expect(source, contains('if (widget.user.permissions.canManageAgents)'));
      expect(source, contains('agent.profile ?? AgentProfile('));
    });
  });
}
