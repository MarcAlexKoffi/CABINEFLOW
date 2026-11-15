import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

enum AgentPersonalMediaKind { avatar, identity }

extension AgentPersonalMediaKindX on AgentPersonalMediaKind {
  String get firestoreValue => switch (this) {
    AgentPersonalMediaKind.avatar => 'avatar',
    AgentPersonalMediaKind.identity => 'identity',
  };
}

class AgentPersonalMedia {
  const AgentPersonalMedia({
    required this.agentId,
    required this.kind,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.sizeBytes,
    this.createdAt,
    this.updatedAt,
  });

  final String agentId;
  final AgentPersonalMediaKind kind;
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final int sizeBytes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static AgentPersonalMedia? fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) return null;
    final String? agentId = data['agentId'] as String?;
    final String? kindValue = data['kind'] as String?;
    final String? fileName = data['fileName'] as String?;
    final String? mimeType = data['mimeType'] as String?;
    final Blob? blob = data['contentBytes'] as Blob?;
    final int? sizeBytes = data['sizeBytes'] as int?;
    if (agentId == null ||
        kindValue == null ||
        fileName == null ||
        mimeType == null ||
        blob == null ||
        sizeBytes == null) {
      return null;
    }
    final AgentPersonalMediaKind? kind = switch (kindValue) {
      'avatar' => AgentPersonalMediaKind.avatar,
      'identity' => AgentPersonalMediaKind.identity,
      _ => null,
    };
    if (kind == null) return null;
    return AgentPersonalMedia(
      agentId: agentId,
      kind: kind,
      fileName: fileName,
      mimeType: mimeType,
      bytes: blob.bytes,
      sizeBytes: sizeBytes,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class PreparedAgentMedia {
  const PreparedAgentMedia({
    required this.kind,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final AgentPersonalMediaKind kind;
  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  int get sizeBytes => bytes.lengthInBytes;
}
