import 'dart:typed_data';

import 'package:cabine_flow/features/auth/domain/models/staff_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStaffProfileRepository {
  SupabaseStaffProfileRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String tableName = 'staff_profiles';
  static const String auditTableName = 'staff_profile_audit_events';
  static const String bucketName = 'agent-personal';
  static const int avatarMaxBytes = 250000;
  static const int avatarMaxDimension = 512;

  final SupabaseClient _client;

  Future<StaffProfile?> fetchProfile(String firebaseUid) async {
    final String uid = firebaseUid.trim();
    if (uid.isEmpty) return null;
    final Map<String, dynamic>? row = await _client
        .from(tableName)
        .select()
        .eq('firebase_uid', uid)
        .maybeSingle();
    return row == null ? null : StaffProfile.fromMap(row);
  }

  Stream<StaffProfile?> watchProfile(String firebaseUid) {
    final String uid = firebaseUid.trim();
    if (uid.isEmpty) return const Stream<StaffProfile?>.empty();
    return _client
        .from(tableName)
        .stream(primaryKey: const <String>['firebase_uid'])
        .eq('firebase_uid', uid)
        .map((List<Map<String, dynamic>> rows) {
          if (rows.isEmpty) return null;
          return StaffProfile.fromMap(rows.first);
        });
  }

  Future<List<StaffProfile>> fetchProfiles({String? role}) async {
    dynamic query = _client.from(tableName).select();
    final String roleFilter = role?.trim() ?? '';
    if (roleFilter.isNotEmpty) {
      query = query.eq('role', roleFilter);
    }
    final List<dynamic> rows = await query.order('first_name');
    return rows
        .whereType<Map<String, dynamic>>()
        .map(StaffProfile.fromMap)
        .toList(growable: false);
  }

  Future<int> syncStaffProfiles() async {
    final Object? raw = await _client.rpc('izytel_sync_staff_profiles');
    return raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
  }

  Future<StaffProfile> saveOwnProfile(StaffProfileDraft draft) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'p_first_name': draft.firstName.trim(),
      'p_last_name': draft.lastName.trim(),
      'p_email': draft.email.trim(),
      'p_phone_number': draft.phoneNumber.trim(),
      'p_secondary_phone': draft.secondaryPhone.trim(),
      'p_date_of_birth': _dateOnly(draft.dateOfBirth),
      'p_address': draft.address.trim(),
      'p_city': draft.city.trim(),
      'p_emergency_contact_name': draft.emergencyContactName.trim(),
      'p_emergency_contact_phone': draft.emergencyContactPhone.trim(),
      'p_avatar_path': _nullable(draft.avatarPath),
      'p_identity_document_type': _nullable(draft.identityDocumentType),
      'p_identity_document_number': draft.identityDocumentNumber.trim(),
      'p_identity_document_path': _nullable(draft.identityDocumentPath),
      'p_identity_document_file_name': _nullable(draft.identityDocumentFileName),
      'p_identity_document_mime_type': _nullable(draft.identityDocumentMimeType),
    };
    final Object? raw = await _client.rpc(
      'izytel_save_own_staff_profile',
      params: params,
    );
    return _profileFromRpc(raw);
  }

  Future<StaffProfile> reviewProfile({
    required String firebaseUid,
    required StaffProfileVerificationStatus status,
    String? note,
  }) async {
    final Object? raw = await _client.rpc(
      'izytel_review_staff_profile',
      params: <String, dynamic>{
        'p_firebase_uid': firebaseUid.trim(),
        'p_status': status.databaseValue,
        'p_note': note?.trim(),
      },
    );
    return _profileFromRpc(raw);
  }

  Future<List<StaffProfileAuditEvent>> fetchAuditEvents(
    String firebaseUid, {
    int limit = 20,
  }) async {
    final List<dynamic> rows = await _client
        .from(auditTableName)
        .select()
        .eq('firebase_uid', firebaseUid.trim())
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(StaffProfileAuditEvent.fromMap)
        .toList(growable: false);
  }

  Future<String?> fetchAvatarUrl(
    String firebaseUid, {
    String? knownPath,
    int expiresInSeconds = 3600,
  }) async {
    final String uid = firebaseUid.trim();
    if (uid.isEmpty) return null;
    String? path = _nullable(knownPath);
    if (path == null) {
      try {
        final StaffProfile? profile = await fetchProfile(uid);
        path = profile?.avatarPath;
      } on PostgrestException {
        path = null;
      }
    }
    if (path == null) {
      final Object? raw = await _client.rpc(
        'izytel_staff_directory_avatar_path',
        params: <String, dynamic>{'p_staff_uid': uid},
      );
      path = _nullable(raw?.toString());
    }
    if (path == null || path.isEmpty) return null;
    try {
      return await _client.storage
          .from(bucketName)
          .createSignedUrl(path, expiresInSeconds);
    } on StorageException {
      return null;
    }
  }

  Future<String?> fetchIdentityDocumentUrl(
    String firebaseUid, {
    int expiresInSeconds = 900,
  }) async {
    final StaffProfile? profile = await fetchProfile(firebaseUid);
    final String? path = profile?.identityDocumentPath;
    if (path == null || path.isEmpty) return null;
    return _client.storage.from(bucketName).createSignedUrl(path, expiresInSeconds);
  }

  Future<String> uploadPreparedOwnAvatar({
    required String firebaseUid,
    required Uint8List bytes,
  }) async {
    final String uid = firebaseUid.trim();
    _assertOwnUid(uid);
    final String path = '$uid/avatar/profile.jpg';
    await _client.storage.from(bucketName).uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        upsert: true,
        contentType: 'image/jpeg',
        cacheControl: '60',
      ),
    );
    return path;
  }

  Future<String> uploadOwnAvatar({
    required String firebaseUid,
    required Uint8List source,
    required String fallbackDisplayName,
  }) async {
    final String uid = firebaseUid.trim();
    _assertOwnUid(uid);
    final Uint8List bytes = prepareAvatar(source);
    final String path = await uploadPreparedOwnAvatar(
      firebaseUid: uid,
      bytes: bytes,
    );

    final StaffProfile? current = await fetchProfile(uid);
    final StaffProfileDraft draft = _draftWithAvatar(
      current: current,
      fallbackDisplayName: fallbackDisplayName,
      avatarPath: path,
    );
    await saveOwnProfile(draft);

    final String signed = await _client.storage
        .from(bucketName)
        .createSignedUrl(path, 3600);
    final String separator = signed.contains('?') ? '&' : '?';
    return '$signed${separator}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Uint8List prepareAvatar(Uint8List source) {
    if (source.isEmpty) {
      throw StateError('La photo sélectionnée est vide.');
    }
    img.Image? decoded = img.decodeImage(source);
    if (decoded == null) {
      throw StateError('La photo sélectionnée n’est pas une image valide.');
    }
    decoded = img.bakeOrientation(decoded);
    final int longestSide = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    if (longestSide > avatarMaxDimension) {
      final double ratio = avatarMaxDimension / longestSide;
      decoded = img.copyResize(
        decoded,
        width: (decoded.width * ratio).round(),
        height: (decoded.height * ratio).round(),
        interpolation: img.Interpolation.linear,
      );
    }

    Uint8List? last;
    for (int quality = 88; quality >= 40; quality -= 6) {
      final Uint8List encoded = Uint8List.fromList(
        img.encodeJpg(decoded, quality: quality),
      );
      last = encoded;
      if (encoded.lengthInBytes <= avatarMaxBytes) return encoded;
    }
    throw StateError(
      'La photo reste trop lourde après compression '
      '(${last?.lengthInBytes ?? source.lengthInBytes} octets).',
    );
  }

  StaffProfileDraft _draftWithAvatar({
    required StaffProfile? current,
    required String fallbackDisplayName,
    required String avatarPath,
  }) {
    if (current != null) {
      return StaffProfileDraft(
        firstName: current.firstName,
        lastName: current.lastName,
        email: current.email,
        phoneNumber: current.phoneNumber,
        secondaryPhone: current.secondaryPhone,
        dateOfBirth: current.dateOfBirth,
        address: current.address,
        city: current.city,
        emergencyContactName: current.emergencyContactName,
        emergencyContactPhone: current.emergencyContactPhone,
        avatarPath: avatarPath,
        identityDocumentType: current.identityDocumentType,
        identityDocumentNumber: current.identityDocumentNumber,
        identityDocumentPath: current.identityDocumentPath,
        identityDocumentFileName: current.identityDocumentFileName,
        identityDocumentMimeType: current.identityDocumentMimeType,
      );
    }

    final List<String> names = fallbackDisplayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    return StaffProfileDraft(
      firstName: names.isEmpty ? 'Staff' : names.first,
      lastName: names.length > 1 ? names.skip(1).join(' ') : '',
      email: '',
      phoneNumber: '',
      secondaryPhone: '',
      address: '',
      city: '',
      emergencyContactName: '',
      emergencyContactPhone: '',
      avatarPath: avatarPath,
    );
  }

  StaffProfile _profileFromRpc(Object? raw) {
    if (raw is Map<String, dynamic>) return StaffProfile.fromMap(raw);
    if (raw is Map) {
      return StaffProfile.fromMap(Map<String, dynamic>.from(raw));
    }
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return StaffProfile.fromMap(
        Map<String, dynamic>.from(raw.first as Map),
      );
    }
    throw StateError('Réponse profil Staff Supabase invalide.');
  }

  void _assertOwnUid(String uid) {
    final String current = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (uid.isEmpty || current.isEmpty || current != uid) {
      throw StateError('La session ne correspond pas au profil Staff à modifier.');
    }
  }

  String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    String two(int input) => input.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  String? _nullable(String? value) {
    final String text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
