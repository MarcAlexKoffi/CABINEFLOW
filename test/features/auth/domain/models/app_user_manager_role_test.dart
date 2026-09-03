import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Manager expose son libelle et ses alias backend', () {
    const AppUser user = AppUser(
      id: 'MAN-001',
      name: 'Manager Test',
      phoneNumber: '0700000000',
      role: UserRole.manager,
    );

    expect(user.roleLabel, 'Manager');
    expect(user.isManager, isTrue);
    expect(user.firestoreCompatibilityRole, 'supervisor');
    expect(user.supabaseStaffRole, 'manager');
  });

  test('supervisor historique est presente comme Manager', () {
    const AppUser user = AppUser(
      id: 'SUP-001',
      name: 'Manager Legacy',
      phoneNumber: '0700000001',
      role: UserRole.supervisor,
    );

    expect(user.roleLabel, 'Manager');
    expect(user.isManager, isTrue);
    expect(user.permissions.canAssignOrders, isTrue);
    expect(user.firestoreCompatibilityRole, 'supervisor');
  });

  test('Manager garde les operations sans privileges Admin sensibles', () {
    const UserPermissions permissions = UserPermissions.manager;

    expect(permissions.canAssignOrders, isTrue);
    expect(permissions.canConfirmPayments, isTrue);
    expect(permissions.canResolveAgentIssues, isTrue);
    expect(permissions.canViewOperationalFinances, isTrue);
    expect(permissions.canProcessSupportRequests, isFalse);
    expect(permissions.canManageAgents, isFalse);
    expect(permissions.canManageOffers, isFalse);
    expect(permissions.canManageFailedOrders, isFalse);
    expect(permissions.canManageRefunds, isFalse);
    expect(permissions.canManageFinanceSettings, isFalse);
    expect(permissions.canRunPhase5Backfill, isFalse);
  });
}
