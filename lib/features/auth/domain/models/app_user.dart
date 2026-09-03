enum UserRole { administrator, manager, supervisor, operator, agent }

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.role,
  });

  final String id;
  final String name;
  final String phoneNumber;
  final UserRole role;

  String get roleLabel {
    switch (role) {
      case UserRole.administrator:
        return 'Administrateur';

      case UserRole.manager:
        return 'Manager';

      // Compatibilite Firestore temporaire : un document staff dont le role
      // backend vaut encore `supervisor` est presente comme Manager dans l UI.
      case UserRole.supervisor:
        return 'Manager';

      case UserRole.operator:
        return 'Opérateur';

      case UserRole.agent:
        return 'Agent';
    }
  }
}
