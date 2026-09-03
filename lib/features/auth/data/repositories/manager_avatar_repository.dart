import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Avatar du compte Manager stocké dans le bucket privé déjà utilisé par
/// l'application. Le chemin reste strictement rattaché à l'UID Firebase du
/// compte connecté, donc aucune règle Firestore n'est nécessaire.
class ManagerAvatarRepository {
  ManagerAvatarRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String bucketName = 'agent-personal';
  static const int _maxDimension = 512;
  static const int _targetBytes = 350000;

  final SupabaseClient _client;

  String _avatarPath(String uid) => '${uid.trim()}/avatar/profile.jpg';

  Future<String?> fetchAvatarUrl(String uid) async {
    final String cleanUid = uid.trim();
    if (cleanUid.isEmpty) return null;

    try {
      final files = await _client.storage
          .from(bucketName)
          .list(path: '$cleanUid/avatar');
      final bool exists = files.any((file) => file.name == 'profile.jpg');
      if (!exists) return null;

      return _client.storage
          .from(bucketName)
          .createSignedUrl(_avatarPath(cleanUid), 3600);
    } on StorageException {
      return null;
    }
  }

  Future<String> uploadAvatar({
    required String uid,
    required Uint8List source,
  }) async {
    final String cleanUid = uid.trim();
    if (cleanUid.isEmpty) {
      throw StateError('Compte Manager invalide.');
    }
    if (source.isEmpty) {
      throw StateError('La photo sélectionnée est vide.');
    }

    final Uint8List prepared = _prepareAvatar(source);
    final String path = _avatarPath(cleanUid);

    await _client.storage.from(bucketName).uploadBinary(
      path,
      prepared,
      fileOptions: const FileOptions(
        upsert: true,
        contentType: 'image/jpeg',
        cacheControl: '60',
      ),
    );

    final String signed = await _client.storage
        .from(bucketName)
        .createSignedUrl(path, 3600);
    final String separator = signed.contains('?') ? '&' : '?';
    return '$signed${separator}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Uint8List _prepareAvatar(Uint8List source) {
    img.Image? decoded = img.decodeImage(source);
    if (decoded == null) {
      throw StateError('La photo sélectionnée n’est pas une image valide.');
    }

    decoded = img.bakeOrientation(decoded);
    final int longestSide = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    if (longestSide > _maxDimension) {
      final double ratio = _maxDimension / longestSide;
      decoded = img.copyResize(
        decoded,
        width: (decoded.width * ratio).round(),
        height: (decoded.height * ratio).round(),
        interpolation: img.Interpolation.linear,
      );
    }

    for (int quality = 88; quality >= 52; quality -= 6) {
      final Uint8List encoded = Uint8List.fromList(
        img.encodeJpg(decoded, quality: quality),
      );
      if (encoded.lengthInBytes <= _targetBytes || quality == 52) {
        return encoded;
      }
    }

    throw StateError('Impossible de préparer la photo de profil.');
  }
}
