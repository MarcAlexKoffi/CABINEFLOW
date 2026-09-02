import 'dart:typed_data';

import 'package:cabine_flow/features/agents/domain/models/agent_personal_media.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAgentPersonalProfileRepository {
  SupabaseAgentPersonalProfileRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String tableName = 'agent_personal_profiles';
  static const String bucketName = 'agent-personal';

  static const int avatarMaxBytes = 250000;
  static const int identityMaxBytes = 850000;
  static const int avatarMaxDimension = 512;
  static const int identityMaxDimension = 1600;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchProfile(String agentId) async {
    final Map<String, dynamic>? row = await _client
        .from(tableName)
        .select()
        .eq('firebase_uid', agentId)
        .maybeSingle();
    if (row == null) return null;
    return _toUiProfile(row);
  }

  Stream<Map<String, dynamic>?> watchProfile(String agentId) {
    return _client
        .from(tableName)
        .stream(primaryKey: const <String>['firebase_uid'])
        .eq('firebase_uid', agentId)
        .map((List<Map<String, dynamic>> rows) {
          if (rows.isEmpty) return null;
          return _toUiProfile(rows.first);
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

  Future<AgentPersonalMedia?> fetchMedia({
    required String agentId,
    required AgentPersonalMediaKind kind,
    Map<String, dynamic>? profile,
  }) async {
    final Map<String, dynamic>? current =
        profile ?? await fetchProfile(agentId);
    if (current == null) return null;

    final String? path = kind == AgentPersonalMediaKind.avatar
        ? _nullableString(current['avatarStoragePath'])
        : _nullableString(current['identityDocumentStoragePath']);
    if (path == null) return null;

    final Uint8List bytes = await _client.storage
        .from(bucketName)
        .download(path);
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
        'La session Firebase ne correspond pas au profil Agent à modifier.',
      );
    }

    final Map<String, dynamic>? existing = await _client
        .from(tableName)
        .select()
        .eq('firebase_uid', agentId)
        .maybeSingle();

    String? avatarPath = _nullableString(existing?['avatar_path']);
    String? identityPath = _nullableString(existing?['identity_document_path']);
    String? identityFileName = _nullableString(
      existing?['identity_document_file_name'],
    );
    String? identityMimeType = _nullableString(
      existing?['identity_document_mime_type'],
    );

    if (avatar != null) {
      avatarPath = '$agentId/avatar/profile.jpg';
      await _client.storage
          .from(bucketName)
          .uploadBinary(
            avatarPath,
            avatar.bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
              cacheControl: '3600',
            ),
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
      await _client.storage
          .from(bucketName)
          .uploadBinary(
            identityPath,
            identityDocument.bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: identityDocument.mimeType,
              cacheControl: '3600',
            ),
          );
    }

    final Map<String, dynamic> row = <String, dynamic>{
      'firebase_uid': agentId,
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'date_of_birth': _dateOnly(dateOfBirth),
      'address': address.trim(),
      'city': city.trim(),
      'contact1': contact1.trim(),
      'contact2': contact2.trim(),
      'emergency_contact_name': emergencyContactName.trim(),
      'emergency_contact_phone': emergencyContactPhone.trim(),
      'identity_document_type': identityDocumentType.trim(),
      'identity_document_number': identityDocumentNumber.trim(),
      'avatar_path': avatarPath,
      'identity_document_path': identityPath,
      'identity_document_file_name': identityFileName,
      'identity_document_mime_type': identityMimeType,
      'verification_status': _toDatabaseVerificationStatus(verificationStatus),
      'verification_note': verificationNote?.trim().isEmpty == true
          ? null
          : verificationNote?.trim(),
    };

    await _client.from(tableName).upsert(row, onConflict: 'firebase_uid');

    if (identityDocument != null &&
        previousIdentityPath != null &&
        previousIdentityPath != identityPath) {
      try {
        await _client.storage.from(bucketName).remove(<String>[
          previousIdentityPath,
        ]);
      } on StorageException {
        // Le nouveau fichier et la ligne SQL sont déjà valides. L'ancien objet
        // peut être nettoyé ultérieurement sans bloquer l'enregistrement.
      }
    }
  }

  PreparedAgentMedia prepareAvatar({
    required Uint8List source,
    String fileName = 'avatar.jpg',
  }) {
    final Uint8List bytes = _compressImage(
      source,
      maxBytes: avatarMaxBytes,
      maxDimension: avatarMaxDimension,
      label: 'La photo de profil',
    );
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
    final Uint8List bytes = _compressImage(
      source,
      maxBytes: identityMaxBytes,
      maxDimension: identityMaxDimension,
      label: 'La pièce d’identité',
    );
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
      throw StateError(
        'Le fichier sélectionné ne semble pas être un PDF valide.',
      );
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

  Map<String, dynamic> _toUiProfile(Map<String, dynamic> row) {
    final String? avatarPath = _nullableString(row['avatar_path']);
    final String? identityPath = _nullableString(row['identity_document_path']);
    return <String, dynamic>{
      'userId': _string(row['firebase_uid']),
      'firstName': _string(row['first_name']),
      'lastName': _string(row['last_name']),
      'dateOfBirth': _date(row['date_of_birth']),
      'address': _string(row['address']),
      'city': _string(row['city']),
      'contact1': _string(row['contact1']),
      'contact2': _string(row['contact2']),
      'emergencyContactName': _string(row['emergency_contact_name']),
      'emergencyContactPhone': _string(row['emergency_contact_phone']),
      'identityDocumentType': _string(row['identity_document_type']),
      'identityDocumentNumber': _string(row['identity_document_number']),
      // Noms de compatibilité gardés temporairement pour ne pas réécrire l'UI.
      // Ces chemins pointent désormais vers Supabase Storage, pas Firebase.
      'avatarStoragePath': avatarPath,
      'identityDocumentStoragePath': identityPath,
      'hasAvatarMedia': avatarPath != null,
      'hasIdentityDocumentMedia': identityPath != null,
      'identityDocumentFileName': _nullableString(
        row['identity_document_file_name'],
      ),
      'identityDocumentMimeType': _nullableString(
        row['identity_document_mime_type'],
      ),
      'verificationStatus': _toUiVerificationStatus(
        _string(row['verification_status']),
      ),
      'verificationNote': _nullableString(row['verification_note']),
      'createdAt': _date(row['created_at']),
      'updatedAt': _date(row['updated_at']),
    };
  }

  Uint8List _compressImage(
    Uint8List source, {
    required int maxBytes,
    required int maxDimension,
    required String label,
  }) {
    img.Image? decoded = img.decodeImage(source);
    if (decoded == null) {
      throw StateError('$label n’est pas une image valide.');
    }
    decoded = img.bakeOrientation(decoded);
    decoded = _resize(decoded, maxDimension);

    const List<int> qualities = <int>[88, 80, 72, 64, 56, 48, 40, 34];
    Uint8List? last;
    img.Image current = decoded;
    for (int pass = 0; pass < 5; pass++) {
      for (final int quality in qualities) {
        final Uint8List encoded = img.encodeJpg(current, quality: quality);
        last = encoded;
        if (encoded.lengthInBytes <= maxBytes) return encoded;
      }
      final int nextWidth = (current.width * 0.82).round();
      final int nextHeight = (current.height * 0.82).round();
      if (nextWidth < 240 || nextHeight < 240) break;
      current = img.copyResize(
        current,
        width: nextWidth,
        height: nextHeight,
        interpolation: img.Interpolation.linear,
      );
    }
    throw StateError(
      '$label reste trop lourde après compression '
      '(${last?.lengthInBytes ?? source.lengthInBytes} octets).',
    );
  }

  img.Image _resize(img.Image source, int maxDimension) {
    if (source.width <= maxDimension && source.height <= maxDimension) {
      return source;
    }
    if (source.width >= source.height) {
      return img.copyResize(
        source,
        width: maxDimension,
        interpolation: img.Interpolation.linear,
      );
    }
    return img.copyResize(
      source,
      height: maxDimension,
      interpolation: img.Interpolation.linear,
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
    const int maxStemLength = 180;
    if (stem.length > maxStemLength) {
      stem = stem.substring(0, maxStemLength);
    }
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

  String _dateOnly(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  String _toDatabaseVerificationStatus(String value) {
    return switch (value.trim()) {
      'pendingReview' => 'pending_review',
      'needsCorrection' => 'needs_correction',
      'verified' => 'verified',
      _ => 'incomplete',
    };
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
