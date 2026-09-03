import 'package:cabine_flow/features/auth/domain/models/app_user.dart';

/// Matrice fonctionnelle IzyTel.
///
/// Elle separe les droits visibles dans Flutter des valeurs historiques encore
/// attendues par certains backends. Pendant la migration Manager, Firestore
/// conserve `supervisor` comme valeur technique et Supabase utilise `manager`.
class UserPermissions {
  const UserPermissions({
    required this.canAccessStaffShell,
    required this.canAssignOrders,
    required this.canConfirmPayments,
    required this.canViewSupportRequests,
    required this.canProcessSupportRequests,
    required this.canViewAgentDirectory,
    required this.canResolveAgentIssues,
    required this.canViewOperationalFinances,
    required this.canManageAgents,
    required this.canManageOffers,
    required this.canManageFailedOrders,
    required this.canManageRefunds,
    required this.canManageFinanceSettings,
    required this.canRunPhase5Backfill,
  });

  final bool canAccessStaffShell;
  final bool canAssignOrders;
  final bool canConfirmPayments;
  final bool canViewSupportRequests;
  final bool canProcessSupportRequests;
  final bool canViewAgentDirectory;
  final bool canResolveAgentIssues;
  final bool canViewOperationalFinances;
  final bool canManageAgents;
  final bool canManageOffers;
  final bool canManageFailedOrders;
  final bool canManageRefunds;
  final bool canManageFinanceSettings;
  final bool canRunPhase5Backfill;

  static const UserPermissions administrator = UserPermissions(
    canAccessStaffShell: true,
    canAssignOrders: true,
    canConfirmPayments: true,
    canViewSupportRequests: true,
    canProcessSupportRequests: true,
    canViewAgentDirectory: true,
    canResolveAgentIssues: true,
    canViewOperationalFinances: true,
    canManageAgents: true,
    canManageOffers: true,
    canManageFailedOrders: true,
    canManageRefunds: true,
    canManageFinanceSettings: true,
    canRunPhase5Backfill: true,
  );

  /// Manager fonctionnel. Les droits marques false restent volontairement
  /// bloques tant que leurs ecrans reposent sur des ecritures Firestore
  /// strictement Admin. Cela evite toute publication de nouvelles rules.
  static const UserPermissions manager = UserPermissions(
    canAccessStaffShell: true,
    canAssignOrders: true,
    canConfirmPayments: true,
    canViewSupportRequests: true,
    canProcessSupportRequests: false,
    canViewAgentDirectory: true,
    canResolveAgentIssues: true,
    canViewOperationalFinances: true,
    canManageAgents: false,
    canManageOffers: false,
    canManageFailedOrders: false,
    canManageRefunds: false,
    canManageFinanceSettings: false,
    canRunPhase5Backfill: false,
  );

  /// Ancien role conserve uniquement pour compatibilite de donnees.
  static const UserPermissions legacyOperator = UserPermissions(
    canAccessStaffShell: true,
    canAssignOrders: false,
    canConfirmPayments: true,
    canViewSupportRequests: true,
    canProcessSupportRequests: false,
    canViewAgentDirectory: true,
    canResolveAgentIssues: false,
    canViewOperationalFinances: false,
    canManageAgents: false,
    canManageOffers: false,
    canManageFailedOrders: false,
    canManageRefunds: false,
    canManageFinanceSettings: false,
    canRunPhase5Backfill: false,
  );

  static const UserPermissions agent = UserPermissions(
    canAccessStaffShell: false,
    canAssignOrders: false,
    canConfirmPayments: false,
    canViewSupportRequests: false,
    canProcessSupportRequests: false,
    canViewAgentDirectory: false,
    canResolveAgentIssues: false,
    canViewOperationalFinances: false,
    canManageAgents: false,
    canManageOffers: false,
    canManageFailedOrders: false,
    canManageRefunds: false,
    canManageFinanceSettings: false,
    canRunPhase5Backfill: false,
  );
}

extension AppUserPermissionsX on AppUser {
  UserPermissions get permissions {
    switch (role) {
      case UserRole.administrator:
        return UserPermissions.administrator;
      case UserRole.manager:
      case UserRole.supervisor:
        return UserPermissions.manager;
      case UserRole.operator:
        return UserPermissions.legacyOperator;
      case UserRole.agent:
        return UserPermissions.agent;
    }
  }

  bool get isManager =>
      role == UserRole.manager || role == UserRole.supervisor;

  /// Valeur a conserver dans /users tant que les rules Firestore publiees
  /// reconnaissent `supervisor` mais pas encore `manager`.
  String get firestoreCompatibilityRole {
    switch (role) {
      case UserRole.administrator:
        return 'admin';
      case UserRole.manager:
      case UserRole.supervisor:
        return 'supervisor';
      case UserRole.operator:
        return 'operator';
      case UserRole.agent:
        return 'agent';
    }
  }

  /// Role attendu par le registre Supabase izytel_staff_access.
  String? get supabaseStaffRole {
    switch (role) {
      case UserRole.administrator:
        return 'admin';
      case UserRole.manager:
      case UserRole.supervisor:
        return 'manager';
      case UserRole.operator:
      case UserRole.agent:
        return null;
    }
  }
}
