import 'dart:typed_data';

import 'package:cabine_flow/features/orders/domain/models/order_proof.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Phase 5B1: source de verite Supabase pour les preuves de traitement.
///
/// Les nouvelles preuves ne sont plus stockees comme Blob dans Firestore.
/// Le bucket reste prive et les RLS limitent l'Agent a ses propres commandes
/// deja remises au flux de traitement, tandis que le staff autorise est en
/// lecture seule.
class SupabaseOrderProofRepository {
  SupabaseOrderProofRepository({
    SupabaseClient? client,
    FirebaseAuth? firebaseAuth,
  }) : _client = client ?? Supabase.instance.client,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  static const String tableName = 'phase5_order_proofs';
  static const String bucketName = 'order-proofs';
  static const int maximumProofBytes = 750000;

  final SupabaseClient _client;
  final FirebaseAuth _firebaseAuth;

  Future<OrderProof?> fetchProof({required String orderId}) async {
    final String cleanedOrderId = orderId.trim();
    if (cleanedOrderId.isEmpty) return null;

    final Map<String, dynamic>? row = await _client
        .from(tableName)
        .select()
        .eq('order_id', cleanedOrderId)
        .maybeSingle();
    if (row == null) return null;

    final String storagePath = _string(row['storage_path']);
    if (storagePath.isEmpty) return null;

    final Uint8List bytes = await _client.storage
        .from(bucketName)
        .download(storagePath);
    return _fromRow(row, bytes);
  }

  Future<bool> hasAgentProof({
    required String orderId,
    required String agentId,
  }) async {
    final String cleanedAgentId = _requireCurrentAgent(agentId);
    final String cleanedOrderId = orderId.trim();
    if (cleanedOrderId.isEmpty) return false;

    final Map<String, dynamic>? row = await _client
        .from(tableName)
        .select('order_id')
        .eq('order_id', cleanedOrderId)
        .eq('agent_id', cleanedAgentId)
        .maybeSingle();
    return row != null;
  }

  Future<OrderProof> saveProof({
    required String orderId,
    required String orderReference,
    required String agentId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final String cleanedAgentId = _requireCurrentAgent(agentId);
    final String cleanedOrderId = orderId.trim();
    final String cleanedReference = orderReference.trim();
    final String cleanedFileName = fileName.trim();
    final String cleanedMimeType = mimeType.trim().toLowerCase();
    final Uint8List proofBytes = Uint8List.fromList(bytes);

    if (cleanedOrderId.isEmpty) {
      throw StateError('La commande est invalide.');
    }
    if (cleanedReference.length < 4 || cleanedReference.length > 80) {
      throw StateError('La reference de commande est invalide.');
    }
    if (cleanedFileName.isEmpty || cleanedFileName.length > 120) {
      throw StateError('Le nom du fichier de preuve est invalide.');
    }
    if (cleanedMimeType != 'image/jpeg') {
      throw StateError('La preuve doit etre enregistree au format JPEG.');
    }
    if (proofBytes.isEmpty) {
      throw StateError('La preuve est vide.');
    }
    if (proofBytes.lengthInBytes > maximumProofBytes) {
      throw StateError('La preuve depasse la taille maximale autorisee.');
    }

    final String storagePath = '$cleanedAgentId/$cleanedOrderId/proof.jpg';
    final Map<String, dynamic>? previous = await _client
        .from(tableName)
        .select('order_id, storage_path')
        .eq('order_id', cleanedOrderId)
        .maybeSingle();

    await _client.storage
        .from(bucketName)
        .uploadBinary(
          storagePath,
          proofBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
            cacheControl: '3600',
          ),
        );

    try {
      await _client.from(tableName).upsert(<String, dynamic>{
        'order_id': cleanedOrderId,
        'order_reference': cleanedReference,
        'agent_id': cleanedAgentId,
        'storage_path': storagePath,
        'file_name': cleanedFileName,
        'mime_type': cleanedMimeType,
        'size_bytes': proofBytes.lengthInBytes,
      }, onConflict: 'order_id');
    } catch (_) {
      if (previous == null) {
        try {
          await _client.storage.from(bucketName).remove(<String>[storagePath]);
        } catch (_) {
          // L'objet orphelin prive pourra etre remplace au prochain essai.
        }
      }
      rethrow;
    }

    final Map<String, dynamic>? saved = await _client
        .from(tableName)
        .select()
        .eq('order_id', cleanedOrderId)
        .maybeSingle();
    if (saved == null) {
      throw StateError('La preuve vient d etre enregistree mais reste illisible.');
    }
    return _fromRow(saved, proofBytes);
  }

  Future<Set<String>> fetchProofOrderIdsForStaff() async {
    final List<Map<String, dynamic>> rows = await _client
        .from(tableName)
        .select('order_id');
    return rows
        .map((Map<String, dynamic> row) => _string(row['order_id']))
        .where((String value) => value.isNotEmpty)
        .toSet();
  }

  String _requireCurrentAgent(String agentId) {
    final String expected = agentId.trim();
    final String uid = (_firebaseAuth.currentUser?.uid ?? '').trim();
    if (uid.isEmpty) {
      throw StateError('Aucune session Firebase active.');
    }
    if (expected.isEmpty || uid != expected) {
      throw StateError('Cette session ne correspond pas a l Agent demande.');
    }
    return uid;
  }

  OrderProof _fromRow(Map<String, dynamic> row, Uint8List bytes) {
    final DateTime createdAt = _date(row['created_at']) ?? DateTime.now();
    final DateTime updatedAt = _date(row['updated_at']) ?? createdAt;
    return OrderProof(
      orderId: _string(row['order_id']),
      orderReference: _string(row['order_reference']),
      agentId: _string(row['agent_id']),
      fileName: _string(row['file_name']),
      mimeType: _string(row['mime_type']),
      bytes: bytes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  String _string(Object? value) => value is String ? value.trim() : '';

  DateTime? _date(Object? value) {
    if (value is DateTime) return value.toLocal();
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }
}
