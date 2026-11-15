enum BackofficeAccountRole {
  pending,
  administrator,
  manager,
  operator,
  agent,
  cabiniste,
  unknown,
}

extension BackofficeAccountRoleX on BackofficeAccountRole {
  String get label {
    switch (this) {
      case BackofficeAccountRole.pending:
        return 'En attente';
      case BackofficeAccountRole.administrator:
        return 'Administrateur';
      case BackofficeAccountRole.manager:
        return 'Manager';
      case BackofficeAccountRole.operator:
        return 'Opérateur (legacy)';
      case BackofficeAccountRole.agent:
        return 'Agent';
      case BackofficeAccountRole.cabiniste:
        return 'Cabiniste';
      case BackofficeAccountRole.unknown:
        return 'Inconnu';
    }
  }

  static BackofficeAccountRole fromBackend(String rawValue) {
    switch (rawValue.trim().toLowerCase()) {
      case 'pending':
        return BackofficeAccountRole.pending;
      case 'admin':
      case 'administrator':
        return BackofficeAccountRole.administrator;
      case 'manager':
      case 'supervisor':
        return BackofficeAccountRole.manager;
      case 'operator':
        return BackofficeAccountRole.operator;
      case 'agent':
        return BackofficeAccountRole.agent;
      case 'cabiniste':
      case 'partner':
        return BackofficeAccountRole.cabiniste;
      default:
        return BackofficeAccountRole.unknown;
    }
  }
}

class BackofficeUserAccount {
  const BackofficeUserAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.lastActivityAt,
    this.zoneIds = const <String>[],
    this.authorizedNetworks = const <String>[],
    this.hasRoleConflict = false,
  });

  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final BackofficeAccountRole role;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastActivityAt;
  final List<String> zoneIds;
  final List<String> authorizedNetworks;
  final bool hasRoleConflict;

  BackofficeUserAccount withBusinessDetails({
    List<String>? zoneIds,
    List<String>? authorizedNetworks,
    bool? hasRoleConflict,
  }) => BackofficeUserAccount(
    id: id,
    name: name,
    email: email,
    phoneNumber: phoneNumber,
    role: role,
    isActive: isActive,
    createdAt: createdAt,
    updatedAt: updatedAt,
    lastActivityAt: lastActivityAt,
    zoneIds: zoneIds ?? this.zoneIds,
    authorizedNetworks: authorizedNetworks ?? this.authorizedNetworks,
    hasRoleConflict: hasRoleConflict ?? this.hasRoleConflict,
  );

  bool get isPending => role == BackofficeAccountRole.pending;

  String get statusLabel {
    if (hasRoleConflict) return 'Conflit de rôles';
    if (isPending) return 'En attente';
    return isActive ? 'Actif' : 'Inactif';
  }
}
