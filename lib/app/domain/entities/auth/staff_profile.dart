enum StaffProfileVerificationStatus {
  incomplete,
  pendingReview,
  needsCorrection,
  verified,
}

extension StaffProfileVerificationStatusX on StaffProfileVerificationStatus {
  String get databaseValue => switch (this) {
    StaffProfileVerificationStatus.incomplete => 'incomplete',
    StaffProfileVerificationStatus.pendingReview => 'pending_review',
    StaffProfileVerificationStatus.needsCorrection => 'needs_correction',
    StaffProfileVerificationStatus.verified => 'verified',
  };

  String get label => switch (this) {
    StaffProfileVerificationStatus.incomplete => 'Incomplet',
    StaffProfileVerificationStatus.pendingReview => 'À vérifier',
    StaffProfileVerificationStatus.needsCorrection => 'À corriger',
    StaffProfileVerificationStatus.verified => 'Vérifié',
  };

  static StaffProfileVerificationStatus fromDatabase(Object? raw) {
    return switch (raw?.toString().trim()) {
      'pending_review' => StaffProfileVerificationStatus.pendingReview,
      'needs_correction' => StaffProfileVerificationStatus.needsCorrection,
      'verified' => StaffProfileVerificationStatus.verified,
      _ => StaffProfileVerificationStatus.incomplete,
    };
  }
}

class StaffProfile {
  const StaffProfile({
    required this.firebaseUid,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.secondaryPhone,
    required this.address,
    required this.city,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.identityDocumentNumber,
    required this.verificationStatus,
    this.dateOfBirth,
    this.avatarPath,
    this.identityDocumentType,
    this.identityDocumentPath,
    this.identityDocumentFileName,
    this.identityDocumentMimeType,
    this.verificationNote,
    this.lastActivityAt,
    this.createdAt,
    this.updatedAt,
  });

  final String firebaseUid;
  final String role;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String secondaryPhone;
  final DateTime? dateOfBirth;
  final String address;
  final String city;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String? avatarPath;
  final String? identityDocumentType;
  final String identityDocumentNumber;
  final String? identityDocumentPath;
  final String? identityDocumentFileName;
  final String? identityDocumentMimeType;
  final StaffProfileVerificationStatus verificationStatus;
  final String? verificationNote;
  final DateTime? lastActivityAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName {
    final String value = '$firstName $lastName'.trim();
    return value.isEmpty ? 'Staff IzyTel' : value;
  }

  String get roleLabel => switch (role) {
    'admin' => 'Administrateur',
    'manager' => 'Manager',
    'agent' => 'Agent',
    'cabiniste' => 'Cabiniste',
    _ => role,
  };

  bool get hasIdentityDocument =>
      identityDocumentPath != null && identityDocumentPath!.trim().isNotEmpty;

  factory StaffProfile.fromMap(Map<String, dynamic> row) {
    return StaffProfile(
      firebaseUid: _string(row['firebase_uid']),
      role: _string(row['role']),
      firstName: _string(row['first_name']),
      lastName: _string(row['last_name']),
      email: _string(row['email']),
      phoneNumber: _string(row['phone_number']),
      secondaryPhone: _string(row['secondary_phone']),
      dateOfBirth: _date(row['date_of_birth']),
      address: _string(row['address']),
      city: _string(row['city']),
      emergencyContactName: _string(row['emergency_contact_name']),
      emergencyContactPhone: _string(row['emergency_contact_phone']),
      avatarPath: _nullableString(row['avatar_path']),
      identityDocumentType: _nullableString(row['identity_document_type']),
      identityDocumentNumber: _string(row['identity_document_number']),
      identityDocumentPath: _nullableString(row['identity_document_path']),
      identityDocumentFileName: _nullableString(
        row['identity_document_file_name'],
      ),
      identityDocumentMimeType: _nullableString(
        row['identity_document_mime_type'],
      ),
      verificationStatus: StaffProfileVerificationStatusX.fromDatabase(
        row['verification_status'],
      ),
      verificationNote: _nullableString(row['verification_note']),
      lastActivityAt: _date(row['last_activity_at']),
      createdAt: _date(row['created_at']),
      updatedAt: _date(row['updated_at']),
    );
  }

  static String _string(Object? value) =>
      value is String ? value.trim() : value?.toString().trim() ?? '';

  static String? _nullableString(Object? value) {
    final String text = _string(value);
    return text.isEmpty ? null : text;
  }

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}

class StaffProfileDraft {
  const StaffProfileDraft({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.secondaryPhone,
    required this.address,
    required this.city,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    this.dateOfBirth,
    this.avatarPath,
    this.identityDocumentType,
    this.identityDocumentNumber = '',
    this.identityDocumentPath,
    this.identityDocumentFileName,
    this.identityDocumentMimeType,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String secondaryPhone;
  final DateTime? dateOfBirth;
  final String address;
  final String city;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String? avatarPath;
  final String? identityDocumentType;
  final String identityDocumentNumber;
  final String? identityDocumentPath;
  final String? identityDocumentFileName;
  final String? identityDocumentMimeType;
}

class StaffProfileAuditEvent {
  const StaffProfileAuditEvent({
    required this.id,
    required this.firebaseUid,
    required this.action,
    required this.actorUid,
    required this.actorRole,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String firebaseUid;
  final String action;
  final String actorUid;
  final String actorRole;
  final String? note;
  final DateTime createdAt;

  String get actionLabel {
    if (action == 'profile_created') return 'Profil créé';
    if (action == 'profile_updated') return 'Profil mis à jour';
    if (action.startsWith('verification_')) return 'Vérification modifiée';
    return action;
  }

  factory StaffProfileAuditEvent.fromMap(Map<String, dynamic> row) {
    return StaffProfileAuditEvent(
      id: row['id']?.toString() ?? '',
      firebaseUid: row['firebase_uid']?.toString() ?? '',
      action: row['action']?.toString() ?? '',
      actorUid: row['actor_uid']?.toString() ?? '',
      actorRole: row['actor_role']?.toString() ?? '',
      note: row['note'] is String && (row['note'] as String).trim().isNotEmpty
          ? (row['note'] as String).trim()
          : null,
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
