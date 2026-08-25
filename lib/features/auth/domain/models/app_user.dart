enum UserRole { administrator, supervisor, operator, agent }

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

      case UserRole.supervisor:
        return 'Superviseur';

      case UserRole.operator:
        return 'Opérateur';

      case UserRole.agent:
        return 'Agent';
    }
  }
}
