class TerritoryManager {
  const TerritoryManager({
    required this.firebaseUid,
    required this.displayName,
    required this.email,
    required this.phoneNumber,
    required this.secondaryPhone,
    required this.city,
    required this.address,
    required this.notes,
    required this.accountActive,
    required this.isAvailable,
    this.avatarPath,
    this.lastActivityAt,
    this.createdAt,
    this.updatedAt,
  });

  final String firebaseUid;
  final String displayName;
  final String email;
  final String phoneNumber;
  final String secondaryPhone;
  final String city;
  final String address;
  final String? avatarPath;
  final String notes;
  final bool accountActive;
  final bool isAvailable;
  final DateTime? lastActivityAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get canReceiveZone => accountActive && isAvailable;

  String get contactLabel {
    if (phoneNumber.trim().isNotEmpty) return phoneNumber.trim();
    if (email.trim().isNotEmpty) return email.trim();
    return 'Contact non renseigné';
  }
}

class TerritoryManagerUpdate {
  const TerritoryManagerUpdate({
    required this.displayName,
    required this.email,
    required this.phoneNumber,
    required this.secondaryPhone,
    required this.city,
    required this.address,
    required this.notes,
    required this.isAvailable,
  });

  final String displayName;
  final String email;
  final String phoneNumber;
  final String secondaryPhone;
  final String city;
  final String address;
  final String notes;
  final bool isAvailable;
}

class TerritoryZone {
  const TerritoryZone({
    required this.id,
    required this.name,
    required this.city,
    required this.region,
    required this.isActive,
    this.latitude,
    this.longitude,
    this.managerId,
    this.legacyFirestoreId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String city;
  final String region;
  final double? latitude;
  final double? longitude;
  final String? managerId;
  final bool isActive;
  final String? legacyFirestoreId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPositioned => latitude != null && longitude != null;

  String get displayLabel {
    final List<String> parts = <String>[
      name.trim(),
      city.trim(),
    ].where((String value) => value.isNotEmpty).toList(growable: false);
    return parts.isEmpty ? 'Zone IzyTel' : parts.join(', ');
  }
}

class TerritoryZoneDraft {
  const TerritoryZoneDraft({
    required this.name,
    required this.city,
    required this.region,
    required this.isActive,
    this.latitude,
    this.longitude,
    this.managerId,
  });

  final String name;
  final String city;
  final String region;
  final double? latitude;
  final double? longitude;
  final String? managerId;
  final bool isActive;
}

class TerritoryAuditEvent {
  const TerritoryAuditEvent({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.actorUid,
    required this.actorName,
    required this.actorRole,
    required this.createdAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String action;
  final String actorUid;
  final String actorName;
  final String actorRole;
  final DateTime createdAt;

  String get actionLabel {
    switch (action) {
      case 'created':
        return 'Création';
      case 'updated':
        return 'Mise à jour';
      default:
        return action;
    }
  }
}
