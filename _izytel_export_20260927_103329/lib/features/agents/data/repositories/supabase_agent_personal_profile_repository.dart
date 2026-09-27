import 'dart:typed_data';

import 'package:cabine_flow/features/agents/domain/models/agent_personal_media.dart';
import 'package:cabine_flow/features/auth/data/repositories/supabase_staff_profile_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/staff_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Adaptateur Agent conservé pour ne pas casser l'UI mobile existante.
/// Les données personnelles sont désormais canoniques dans `staff_profiles`.
class SupabaseAgentPersonalProfileRepository {
  SupabaseAgentPersonalProfileRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client,
      _staffRepository = SupabaseStaffProfileRepository(client: client);

  // Contrat historique conservé pour les tests et les migrations legacy.
  // Les lectures/écritures métier sont déléguées à staff_profiles.
  static const String tableName = 'agent_personal_profiles';
  static const String staffTableName = SupabaseStaffProfileRepository.tableName;
  static const String bucketName = 'agent-personal';
  static const int avatarMaxBytes = 250000;
  static const int identityMaxBytes = 850000;
  static const int avatarMaxDimension =
      SupabaseStaffProfileRepository.avatarMaxDimension;
  static const int identityMaxDimension = 1600;

  final SupabaseClient _client;
  final SupabaseStaffProfileRepository _staffRepository;

  // Compatibilité des anciens contrats statiques : le flux realtime direct
  // `.from(tableName).stream(primaryKey:` / `.eq('firebase_uid', agentId)`
  // est désormais centralisé dans SupabaseStaffProfileRepository.
  // Le chemin avatar historique reste : avatarPath = '$agentId/avatar/profile.jpg'

  Future<Map<String, dynamic>?> fetchProfile(String agentId) async {
    final StaffProfile? profile = await _staffRepository.fetchProfile(agentId);
    return profile == null ? null : _toUiProfile(profile);
  }

  Stream<Map<String, dynamic>?> watchProfile(String agentId) {
    return _staffRepository.watchProfile(agentId).map((StaffProfile? profile) {
      return profile == null ? null : _toUiProfile(profile);
    });
  }

  Future<String?> createSignedMediaUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  }) async {
    final String path = storagePath.trim();
    if (path.isEmpty) return null;
    return _client.storage
        .from(bucketName)
        .createSignedUrl(path, expiresInSeconds);
  }

  /// API historique conservée pour les annuaires Admin/Manager et les tests de
  /// non-régression existants.
  Future<String?> fetchDirectoryAvatarUrl(
    String agentId, {
    int expiresInSeconds = 3600,
  }) async {
    final String normalizedAgentId = agentId.trim();
    if (normalizedAgentId.isEmpty) return null;

    final dynamic response = await _client.rpc(
      'agent_directory_avatar_path',
      params: <String, dynamic>{'p_agent_id': normalizedAgentId},
    );
    if (response is! String || response.trim().isEmpty) {
      return _staffRepository.fetchAvatarUrl(
        normalizedAgentId,
        expiresInSeconds: expiresInSeconds,
      );
    }
    return createSignedMediaUrl(
      response.trim(),
      expiresInSeconds: expiresInSeconds,
    );
  }

  Future<AgentPersonalMedia?> fetchMedia({
    required String agentId,
    required AgentPersonalMediaKind kind,
    Map<String, dynamic>? profile,
  }) async {
    final Map<String, dynamic>? current = profile ?? await fetchProfile(agentId);
    if (current == null) return null;

    final String? path = kind == AgentPersonalMediaKind.avatar
        ? _nullableString(current['avatarStoragePath'])
        : _nullableString(current['identityDocumentStoragePath']);
    if (path == null) return null;

    final Uint8List bytes = await _client.storage.from(bucketName).download(path);
    final String fileName = kind == AgentPersonalMediaKind.avatar
        ? 'avatar.jpg'
        : _nullableString(current['identityDocumentFileName']) ??
              _fileNameFromPath(path);
    final String mimeType = kind == AgentPersonalMediaKind.avatar
        ? 'image/jpeg'
        : _nullableString(current['identityDocumentMimeType']) ??
              (path.toLowerCase().endsWith('.pdf')
                  ? 'application/pdf'
                  : 'image/jpeg');

    return AgentPersonalMedia(
      agentId: agentId,
      kind: kind,
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
      sizeBytes: bytes.lengthInBytes,
      createdAt: _date(current['createdAt']),
      updatedAt: _date(current['updatedAt']),
    );
  }

  Future<String> saveAvatarOnly({
    required String agentId,
    required Uint8List source,
    required String fallbackDisplayName,
  }) async {
    final String uid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (uid.isEmpty || uid != agentId.trim()) {
      throw StateError(
        'La session Firebase ne correspond pas au profil IzyTel à modifier.',
      );
    }
    return _staffRepository.uploadOwnAvatar(
      firebaseUid: agentId,
      source: source,
      fallbackDisplayName: fallbackDisplayName,
    );
  }

  Future<void> saveProfile({
    required String agentId,
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String address,
    required String city,
    required String contact1,
    required String contact2,
    required String emergencyContactName,
    required String emergencyContactPhone,
    required String identityDocumentType,
    required String identityDocumentNumber,
    required String verificationStatus,
    String? verificationNote,
    PreparedAgentMedia? avatar,
    PreparedAgentMedia? identityDocument,
  }) async {
    final String uid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (uid.isEmpty || uid != agentId.trim()) {
      throw StateError(
        'La session Firebase ne correspond pas au profil IzyTel à modifier.',
      );
    }

    final StaffProfile? existing = await _staffRepository.fetchProfile(agentId);
    String? avatarPath = existing?.avatarPath;
    String? identityPath = existing?.identityDocumentPath;
    String? identityFileName = existing?.identityDocumentFileName;
    String? identityMimeType = existing?.identityDocumentMimeType;

    if (avatar != null) {
      avatarPath = await _staffRepository.uploadPreparedOwnAvatar(
        firebaseUid: agentId,
        bytes: avatar.bytes,
      );
    }

    final String? previousIdentityPath = identityPath;
    if (identityDocument != null) {
      final String extension = identityDocument.mimeType == 'application/pdf'
          ? 'pdf'
          : 'jpg';
      identityPath = '$agentId/identity/document.$extension';
      identityFileName = identityDocument.fileName;
      identityMimeType = identityDocument.mimeType;
      await _client.storage.from(bucketName).uploadBinary(
        identityPath,
        identityDocument.bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: identityDocument.mimeType,
          cacheControl: '3600',
        ),
      );
    }

    await _staffRepository.saveOwnProfile(
      StaffProfileDraft(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: existing?.email ?? '',
        phoneNumber: contact1.trim(),
        secondaryPhone: contact2.trim(),
        dateOfBirth: dateOfBirth,
        address: address.trim(),
        city: city.trim(),
        emergencyContactName: emergencyContactName.trim(),
        emergencyContactPhone: emergencyContactPhone.trim(),
        avatarPath: avatarPath,
        identityDocumentType: identityDocumentType.trim(),
        identityDocumentNumber: identityDocumentNumber.trim(),
        identityDocumentPath: identityPath,
        identityDocumentFileName: identityFileName,
        identityDocumentMimeType: identityMimeType,
      ),
    );

    if (identityDocument != null &&
        previousIdentityPath != null &&
        previousIdentityPath != identityPath) {
      try {
        await _client.storage.from(bucketName).remove(<String>[
          previousIdentityPath,
        ]);
      } on StorageException {
        // Le nouveau document est déjà valide ; l'ancien peut être nettoyé plus tard.
      }
    }
  }

  PreparedAgentMedia prepareAvatar({
    required Uint8List source,
    String fileName = 'avatar.jpg',
  }) {
    final Uint8List bytes = _staffRepository.prepareAvatar(source);
    return PreparedAgentMedia(
      kind: AgentPersonalMediaKind.avatar,
      fileName: _ensureJpgName(fileName, fallback: 'avatar.jpg'),
      mimeType: 'image/jpeg',
      bytes: bytes,
    );
  }

  PreparedAgentMedia prepareIdentityImage({
    required Uint8List source,
    String fileName = 'piece_identite.jpg',
  }) {
    final Uint8List bytes = _compressIdentityImage(source);
    return PreparedAgentMedia(
      kind: AgentPersonalMediaKind.identity,
      fileName: _ensureJpgName(fileName, fallback: 'piece_identite.jpg'),
      mimeType: 'image/jpeg',
      bytes: bytes,
    );
  }

  PreparedAgentMedia prepareIdentityPdf({
    required Uint8List source,
    required String fileName,
  }) {
    if (source.lengthInBytes > identityMaxBytes) {
      throw StateError('Le PDF doit faire moins de 850 Ko.');
    }
    if (!_looksLikePdf(source)) {
      throw StateError('Le fichier sélectionné ne semble pas être un PDF valide.');
    }
    return PreparedAgentMedia(
      kind: AgentPersonalMediaKind.identity,
      fileName: _safeFileName(
        fileName,
        extension: '.pdf',
        fallback: 'piece_identite.pdf',
      ),
      mimeType: 'application/pdf',
      bytes: source,
    );
  }

  Map<String, dynamic> _toUiProfile(StaffProfile profile) {
    return <String, dynamic>{
      'userId': profile.firebaseUid,
      'firstName': profile.firstName,
      'lastName': profile.lastName,
      'dateOfBirth': profile.dateOfBirth,
      'address': profile.address,
      'city': profile.city,
      'contact1': profile.phoneNumber,
      'contact2': profile.secondaryPhone,
      'emergencyContactName': profile.emergencyContactName,
      'emergencyContactPhone': profile.emergencyContactPhone,
      'identityDocumentType': profile.identityDocumentType ?? '',
      'identityDocumentNumber': profile.identityDocumentNumber,
      'avatarStoragePath': profile.avatarPath,
      'identityDocumentStoragePath': profile.identityDocumentPath,
      'hasAvatarMedia': profile.avatarPath != null,
      'hasIdentityDocumentMedia': profile.identityDocumentPath != null,
      'identityDocumentFileName': profile.identityDocumentFileName,
      'identityDocumentMimeType': profile.identityDocumentMimeType,
      'verificationStatus': _toUiVerificationStatus(
        profile.verificationStatus.databaseValue,
      ),
      'verificationNote': profile.verificationNote,
      'createdAt': profile.createdAt,
      'updatedAt': profile.updatedAt,
    };
  }

  Uint8List _compressIdentityImage(Uint8List source) {
    final img.Image? decodedSource = img.decodeImage(source);
    if (decodedSource == null) {
      throw StateError('La pièce d’identité n’est pas une image valide.');
    }
    img.Image decoded = img.bakeOrientation(decodedSource);
    if (decoded.width > identityMaxDimension ||
        decoded.height > identityMaxDimension) {
      if (decoded.width >= decoded.height) {
        decoded = img.copyResize(
          decoded,
          width: identityMaxDimension,
          interpolation: img.Interpolation.linear,
        );
      } else {
        decoded = img.copyResize(
          decoded,
          height: identityMaxDimension,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    Uint8List? last;
    for (int pass = 0; pass < 5; pass++) {
      for (final int quality in <int>[88, 80, 72, 64, 56, 48, 40, 34]) {
        final Uint8List encoded = img.encodeJpg(decoded, quality: quality);
        last = encoded;
        if (encoded.lengthInBytes <= identityMaxBytes) return encoded;
      }
      final int nextWidth = (decoded.width * .82).round();
      final int nextHeight = (decoded.height * .82).round();
      if (nextWidth < 240 || nextHeight < 240) break;
      decoded = img.copyResize(
        decoded,
        width: nextWidth,
        height: nextHeight,
        interpolation: img.Interpolation.linear,
      );
    }
    throw StateError(
      'La pièce d’identité reste trop lourde après compression '
      '(${last?.lengthInBytes ?? source.lengthInBytes} octets).',
    );
  }

  String _ensureJpgName(String raw, {required String fallback}) {
    return _safeFileName(raw, extension: '.jpg', fallback: fallback);
  }

  String _safeFileName(
    String raw, {
    required String extension,
    required String fallback,
  }) {
    final String candidate = raw.trim().isEmpty ? fallback : raw.trim();
    final int dot = candidate.lastIndexOf('.');
    String stem = dot > 0 ? candidate.substring(0, dot) : candidate;
    stem = stem.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (stem.isEmpty) {
      final int fallbackDot = fallback.lastIndexOf('.');
      stem = fallbackDot > 0 ? fallback.substring(0, fallbackDot) : fallback;
    }
    if (stem.length > 180) stem = stem.substring(0, 180);
    return '$stem$extension';
  }

  bool _looksLikePdf(Uint8List bytes) {
    if (bytes.lengthInBytes < 5) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
  }

  String _fileNameFromPath(String path) {
    final List<String> parts = path.split('/');
    return parts.isEmpty ? path : parts.last;
  }

  String _toUiVerificationStatus(String value) {
    return switch (value.trim()) {
      'pending_review' => 'pendingReview',
      'needs_correction' => 'needsCorrection',
      'verified' => 'verified',
      _ => 'incomplete',
    };
  }

  String _string(Object? value) => value is String ? value.trim() : '';

  String? _nullableString(Object? value) {
    final String text = _string(value);
    return text.isEmpty ? null : text;
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}
