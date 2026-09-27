import 'dart:typed_data';

import 'package:cabine_flow/features/agents/domain/models/agent_personal_media.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

class FirestoreAgentPersonalMediaRepository {
  FirestoreAgentPersonalMediaRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const int avatarMaxBytes = 250000;
  static const int identityMaxBytes = 850000;
  static const int avatarMaxDimension = 512;
  static const int identityMaxDimension = 1600;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> mediaRef({
    required String agentId,
    required AgentPersonalMediaKind kind,
  }) {
    return _firestore
        .collection('agentPersonalMedia')
        .doc(agentId)
        .collection('items')
        .doc(kind.firestoreValue);
  }

  Stream<AgentPersonalMedia?> watch({
    required String agentId,
    required AgentPersonalMediaKind kind,
  }) {
    return mediaRef(
      agentId: agentId,
      kind: kind,
    ).snapshots().map(AgentPersonalMedia.fromSnapshot);
  }

  Future<AgentPersonalMedia?> fetch({
    required String agentId,
    required AgentPersonalMediaKind kind,
  }) async {
    final snapshot = await mediaRef(agentId: agentId, kind: kind).get();
    return AgentPersonalMedia.fromSnapshot(snapshot);
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
      throw StateError(
        'Le PDF doit faire moins de 850 Ko pour rester sous la limite Firestore.',
      );
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

  Map<String, dynamic> createData({
    required String agentId,
    required PreparedAgentMedia media,
  }) {
    return <String, dynamic>{
      'schemaVersion': 1,
      'agentId': agentId,
      'kind': media.kind.firestoreValue,
      'fileName': media.fileName,
      'mimeType': media.mimeType,
      'contentBytes': Blob(media.bytes),
      'sizeBytes': media.sizeBytes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> updateData({required PreparedAgentMedia media}) {
    return <String, dynamic>{
      'schemaVersion': 1,
      'kind': media.kind.firestoreValue,
      'fileName': media.fileName,
      'mimeType': media.mimeType,
      'contentBytes': Blob(media.bytes),
      'sizeBytes': media.sizeBytes,
      'updatedAt': FieldValue.serverTimestamp(),
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
}
