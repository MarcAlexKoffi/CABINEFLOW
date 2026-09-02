import 'dart:typed_data';

enum AgentAvailability { available, unavailable }

enum AgentNetwork { orange, mtn, moov }

extension AgentAvailabilityX on AgentAvailability {
  String get firestoreValue => name;

  String get label {
    switch (this) {
      case AgentAvailability.available:
        return 'Disponible';
      case AgentAvailability.unavailable:
        return 'Indisponible';
    }
  }
}

extension AgentNetworkX on AgentNetwork {
  String get firestoreValue => name;

  String get label {
    switch (this) {
      case AgentNetwork.orange:
        return 'Orange';
      case AgentNetwork.mtn:
        return 'MTN';
      case AgentNetwork.moov:
        return 'Moov';
    }
  }
}

class AgentProfile {
  const AgentProfile({
    required this.userId,
    required this.agentCode,
    required this.availability,
    required this.zoneIds,
    required this.authorizedNetworks,
    required this.activeNetworks,
    required this.orangeCapacity,
    required this.mtnCapacity,
    required this.moovCapacity,
    required this.dailyTransactionLimit,
    required this.maxTransactionsPerDay,
    this.lastCapacityUpdateAt,
    this.lastSeenAt,
    this.createdAt,
    this.updatedAt,
  });

  final String userId;
  final String agentCode;
  final AgentAvailability availability;
  final List<String> zoneIds;
  final List<AgentNetwork> authorizedNetworks;
  final List<AgentNetwork> activeNetworks;
  final int orangeCapacity;
  final int mtnCapacity;
  final int moovCapacity;
  final int dailyTransactionLimit;
  final int maxTransactionsPerDay;
  final DateTime? lastCapacityUpdateAt;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int capacityFor(AgentNetwork network) {
    switch (network) {
      case AgentNetwork.orange:
        return orangeCapacity;
      case AgentNetwork.mtn:
        return mtnCapacity;
      case AgentNetwork.moov:
        return moovCapacity;
    }
  }

  AgentProfile copyWith({
    AgentAvailability? availability,
    List<String>? zoneIds,
    List<AgentNetwork>? authorizedNetworks,
    List<AgentNetwork>? activeNetworks,
    int? orangeCapacity,
    int? mtnCapacity,
    int? moovCapacity,
    int? dailyTransactionLimit,
    int? maxTransactionsPerDay,
    DateTime? lastCapacityUpdateAt,
    DateTime? lastSeenAt,
    DateTime? updatedAt,
  }) {
    return AgentProfile(
      userId: userId,
      agentCode: agentCode,
      availability: availability ?? this.availability,
      zoneIds: zoneIds ?? this.zoneIds,
      authorizedNetworks: authorizedNetworks ?? this.authorizedNetworks,
      activeNetworks: activeNetworks ?? this.activeNetworks,
      orangeCapacity: orangeCapacity ?? this.orangeCapacity,
      mtnCapacity: mtnCapacity ?? this.mtnCapacity,
      moovCapacity: moovCapacity ?? this.moovCapacity,
      dailyTransactionLimit:
          dailyTransactionLimit ?? this.dailyTransactionLimit,
      maxTransactionsPerDay:
          maxTransactionsPerDay ?? this.maxTransactionsPerDay,
      lastCapacityUpdateAt: lastCapacityUpdateAt ?? this.lastCapacityUpdateAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AgentDirectoryEntry {
  const AgentDirectoryEntry({
    required this.userId,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.isActive,
    required this.profile,
  });

  final String userId;
  final String name;
  final String email;
  final String phoneNumber;
  final bool isActive;
  final AgentProfile? profile;

  String get agentCode => profile?.agentCode ?? 'Profil à compléter';

  AgentAvailability get availability =>
      profile?.availability ?? AgentAvailability.unavailable;
}

class StaffAccountSummary {
  const StaffAccountSummary({
    required this.userId,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.isActive,
  });

  final String userId;
  final String name;
  final String email;
  final String phoneNumber;
  final String role;
  final bool isActive;
}

class AgentZone {
  const AgentZone({
    required this.id,
    required this.name,
    required this.city,
    required this.region,
    required this.isActive,
  });

  final String id;
  final String name;
  final String city;
  final String region;
  final bool isActive;

  String get displayLabel {
    if (city.trim().isEmpty) return name;
    return '$name, $city';
  }
}

class AgentIssue {
  const AgentIssue({
    required this.id,
    required this.agentId,
    required this.type,
    required this.description,
    required this.status,
    required this.createdAt,
    this.network,
    this.updatedAt,
    this.resolvedAt,
    this.resolvedBy,
  });

  final String id;
  final String agentId;
  final String type;
  final AgentNetwork? network;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
}

class AgentAdminUpdate {
  const AgentAdminUpdate({
    required this.name,
    required this.phoneNumber,
    required this.isActive,
    required this.zoneIds,
    required this.authorizedNetworks,
    required this.orangeCapacity,
    required this.mtnCapacity,
    required this.moovCapacity,
    required this.dailyTransactionLimit,
    required this.maxTransactionsPerDay,
  });

  final String name;
  final String phoneNumber;
  final bool isActive;
  final List<String> zoneIds;
  final List<AgentNetwork> authorizedNetworks;
  final int orangeCapacity;
  final int mtnCapacity;
  final int moovCapacity;
  final int dailyTransactionLimit;
  final int maxTransactionsPerDay;
}

class AgentOperationalUpdate {
  const AgentOperationalUpdate({
    required this.availability,
    required this.activeNetworks,
    required this.orangeCapacity,
    required this.mtnCapacity,
    required this.moovCapacity,
  });

  final AgentAvailability availability;
  final List<AgentNetwork> activeNetworks;
  final int orangeCapacity;
  final int mtnCapacity;
  final int moovCapacity;
}

class AgentIssueDraft {
  const AgentIssueDraft({
    required this.type,
    required this.description,
    this.network,
  });

  final String type;
  final AgentNetwork? network;
  final String description;
}

enum AgentIdentityDocumentType {
  nationalId,
  passport,
  drivingLicense,
  residencePermit,
  other,
}

enum AgentProfileVerificationStatus {
  incomplete,
  pendingReview,
  verified,
  needsCorrection,
}

extension AgentIdentityDocumentTypeX on AgentIdentityDocumentType {
  String get firestoreValue => name;

  String get label {
    switch (this) {
      case AgentIdentityDocumentType.nationalId:
        return 'Carte nationale d’identité';
      case AgentIdentityDocumentType.passport:
        return 'Passeport';
      case AgentIdentityDocumentType.drivingLicense:
        return 'Permis de conduire';
      case AgentIdentityDocumentType.residencePermit:
        return 'Titre / carte de séjour';
      case AgentIdentityDocumentType.other:
        return 'Autre pièce officielle';
    }
  }
}

extension AgentProfileVerificationStatusX on AgentProfileVerificationStatus {
  String get firestoreValue => name;

  String get label {
    switch (this) {
      case AgentProfileVerificationStatus.incomplete:
        return 'Profil incomplet';
      case AgentProfileVerificationStatus.pendingReview:
        return 'À vérifier';
      case AgentProfileVerificationStatus.verified:
        return 'Vérifié';
      case AgentProfileVerificationStatus.needsCorrection:
        return 'À corriger';
    }
  }
}

class AgentPersonalProfile {
  const AgentPersonalProfile({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.address,
    required this.city,
    required this.contact1,
    required this.contact2,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.identityDocumentType,
    required this.identityDocumentNumber,
    required this.verificationStatus,
    this.dateOfBirth,
    this.avatarStoragePath,
    this.identityDocumentStoragePath,
    this.hasAvatarMedia = false,
    this.hasIdentityDocumentMedia = false,
    this.identityDocumentFileName,
    this.identityDocumentMimeType,
    this.verificationNote,
    this.createdAt,
    this.updatedAt,
  });

  final String userId;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String address;
  final String city;
  final String contact1;
  final String contact2;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final AgentIdentityDocumentType identityDocumentType;
  final String identityDocumentNumber;
  final String? avatarStoragePath;
  final String? identityDocumentStoragePath;
  final bool hasAvatarMedia;
  final bool hasIdentityDocumentMedia;
  final String? identityDocumentFileName;
  final String? identityDocumentMimeType;
  final AgentProfileVerificationStatus verificationStatus;
  final String? verificationNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName => [
    firstName.trim(),
    lastName.trim(),
  ].where((String value) => value.isNotEmpty).join(' ');

  bool get hasAvatar =>
      hasAvatarMedia || avatarStoragePath?.trim().isNotEmpty == true;
  bool get hasIdentityDocument =>
      hasIdentityDocumentMedia ||
      identityDocumentStoragePath?.trim().isNotEmpty == true;

  bool get isComplete =>
      firstName.trim().length >= 2 &&
      lastName.trim().length >= 2 &&
      dateOfBirth != null &&
      address.trim().length >= 3 &&
      city.trim().length >= 2 &&
      contact1.trim().length >= 8 &&
      hasAvatar &&
      hasIdentityDocument;

  int get completionPercent {
    final List<bool> checks = <bool>[
      firstName.trim().length >= 2,
      lastName.trim().length >= 2,
      dateOfBirth != null,
      address.trim().length >= 3,
      city.trim().length >= 2,
      contact1.trim().length >= 8,
      hasAvatar,
      hasIdentityDocument,
    ];
    final int done = checks.where((bool value) => value).length;
    return ((done / checks.length) * 100).round();
  }
}

class AgentPersonalProfileDraft {
  const AgentPersonalProfileDraft({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.address,
    required this.city,
    required this.contact1,
    required this.contact2,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.identityDocumentType,
    required this.identityDocumentNumber,
  });

  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String address;
  final String city;
  final String contact1;
  final String contact2;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final AgentIdentityDocumentType identityDocumentType;
  final String identityDocumentNumber;

  String get displayName => [
    firstName.trim(),
    lastName.trim(),
  ].where((String value) => value.isNotEmpty).join(' ');
}

class AgentProfileFileUpload {
  const AgentProfileFileUpload({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;
}
