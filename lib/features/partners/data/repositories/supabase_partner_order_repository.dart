import 'dart:typed_data';

import 'package:cabine_flow/features/partners/domain/models/partner_order_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabasePartnerOrderRepository {
  SupabasePartnerOrderRepository({
    SupabaseClient? client,
    FirebaseAuth? firebaseAuth,
  }) : _client = client ?? Supabase.instance.client,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  static const String partnerTable = 'partner_accounts';
  static const String capacityTable = 'partner_capacities';
  static const String ordersTable = 'phase4_assignment_orders';
  static const String proofsTable = 'partner_order_proofs';
  static const String successTable = 'partner_success_finalizations';
  static const String proofBucket = 'order-proofs';
  static const int maximumProofBytes = 750000;

  final SupabaseClient _client;
  final FirebaseAuth _firebaseAuth;

  Future<PartnerAccountSnapshot?> fetchOwnAccount() async {
    final String uid = _requireFirebaseUid();
    final Map<String, dynamic>? account = await _client
        .from(partnerTable)
        .select()
        .eq('firebase_uid', uid)
        .maybeSingle();
    if (account == null) return null;

    final String partnerId = _string(account['id']);
    if (partnerId.isEmpty) return null;

    final Map<String, dynamic>? capacity = await _client
        .from(capacityTable)
        .select()
        .eq('partner_id', partnerId)
        .maybeSingle();

    return _accountFromRows(account, capacity);
  }

  Future<List<PartnerOrderSnapshot>> fetchAssignedOrders() async {
    final PartnerAccountSnapshot account = await _requireOwnAccount();
    final List<Map<String, dynamic>> rows = await _client
        .from(ordersTable)
        .select(
          'order_id, order_reference, network, amount, assignment_state, '
          'order_status, assigned_cabiniste_id, assigned_cabiniste_name, '
          'processing_started_at, completed_at, failure_reason, observation, '
          'last_hold_reason, updated_at',
        )
        .eq('assigned_cabiniste_id', account.id)
        .order('updated_at', ascending: false);

    return List<PartnerOrderSnapshot>.unmodifiable(
      rows.map(_orderFromRow),
    );
  }

  Stream<List<PartnerOrderSnapshot>> watchAssignedOrders({
    required String partnerId,
  }) {
    final String cleanedPartnerId = partnerId.trim();
    if (cleanedPartnerId.isEmpty) {
      throw StateError('Partner id is required.');
    }

    return _client
        .from(ordersTable)
        .stream(primaryKey: const <String>['order_id'])
        .eq('assigned_cabiniste_id', cleanedPartnerId)
        .order('updated_at', ascending: false)
        .map(
          (List<Map<String, dynamic>> rows) =>
              List<PartnerOrderSnapshot>.unmodifiable(
                rows.map(_orderFromRow),
              ),
        );
  }

  Future<PartnerOrderSnapshot> accept(String orderId) {
    return _assignmentAction(orderId: orderId, action: 'accept');
  }

  Future<PartnerOrderSnapshot> refuse({
    required String orderId,
    required String reason,
  }) {
    final String cleanedReason = reason.trim();
    if (cleanedReason.length < 3 || cleanedReason.length > 500) {
      throw StateError('Refusal reason is invalid.');
    }
    return _assignmentAction(
      orderId: orderId,
      action: 'refuse',
      reason: cleanedReason,
    );
  }

  Future<PartnerOrderSnapshot> startProcessing(String orderId) {
    return _processingAction(orderId: orderId, action: 'start');
  }

  Future<PartnerOrderSnapshot> hold({
    required String orderId,
    required String reason,
  }) {
    final String cleanedReason = reason.trim();
    if (cleanedReason.length < 3 || cleanedReason.length > 300) {
      throw StateError('Hold reason is invalid.');
    }
    return _processingAction(
      orderId: orderId,
      action: 'hold',
      reason: cleanedReason,
    );
  }

  Future<PartnerOrderSnapshot> resume(String orderId) {
    return _processingAction(orderId: orderId, action: 'resume');
  }

  Future<PartnerOrderSnapshot> fail({
    required String orderId,
    required String reason,
    String? observation,
  }) {
    return _processingAction(
      orderId: orderId,
      action: 'fail',
      reason: reason.trim(),
      observation: observation?.trim(),
    );
  }

  Future<void> updateOwnOperations({
    required bool available,
    required List<String> activeNetworks,
    required int orangeCapacity,
    required int mtnCapacity,
    required int moovCapacity,
  }) async {
    if (orangeCapacity < 0 || mtnCapacity < 0 || moovCapacity < 0) {
      throw StateError('Capacity cannot be negative.');
    }

    await _client.rpc(
      'izytel_update_own_partner_operations',
      params: <String, dynamic>{
        'p_availability': available ? 'available' : 'unavailable',
        'p_active_networks': activeNetworks
            .map((String value) => value.trim().toLowerCase())
            .where((String value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false),
        'p_orange': orangeCapacity,
        'p_mtn': mtnCapacity,
        'p_moov': moovCapacity,
      },
    );
  }

  Future<void> saveProof({
    required String orderId,
    required String fileName,
    required List<int> bytes,
  }) async {
    final String uid = _requireFirebaseUid();
    final String cleanedOrderId = orderId.trim();
    final Uint8List proofBytes = Uint8List.fromList(bytes);

    if (cleanedOrderId.isEmpty) {
      throw StateError('Order id is required.');
    }
    if (proofBytes.isEmpty) {
      throw StateError('Proof is empty.');
    }
    if (proofBytes.lengthInBytes > maximumProofBytes) {
      throw StateError('Proof exceeds the maximum size.');
    }

    await _firebaseAuth.currentUser?.getIdToken(true);

    final String path =
        'partners/$uid/$cleanedOrderId/proof.jpg';
    final Map<String, dynamic>? previous = await _client
        .from(proofsTable)
        .select('order_id, storage_path')
        .eq('order_id', cleanedOrderId)
        .maybeSingle();

    try {
      await _client.storage.from(proofBucket).uploadBinary(
        path,
        proofBytes,
        fileOptions: FileOptions(
          upsert: previous != null,
          contentType: 'image/jpeg',
          cacheControl: '3600',
        ),
      );
    } on StorageException catch (error) {
      final String raw = error.toString().toLowerCase();
      final bool orphanConflict = previous == null &&
          (raw.contains('duplicate') ||
              raw.contains('already exists') ||
              raw.contains('409'));
      if (!orphanConflict) rethrow;

      await _client.storage.from(proofBucket).uploadBinary(
        path,
        proofBytes,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'image/jpeg',
          cacheControl: '3600',
        ),
      );
    }

    try {
      await _client.rpc(
        'phase5_upsert_partner_order_proof',
        params: <String, dynamic>{
          'p_order_id': cleanedOrderId,
          'p_storage_path': path,
          'p_file_name': fileName.trim().isEmpty
              ? 'proof.jpg'
              : fileName.trim(),
          'p_mime_type': 'image/jpeg',
          'p_size_bytes': proofBytes.lengthInBytes,
        },
      );
    } catch (_) {
      if (previous == null) {
        try {
          await _client.storage.from(proofBucket).remove(<String>[path]);
        } catch (_) {
          // A private orphan can be replaced by the next attempt.
        }
      }
      rethrow;
    }
  }

  Future<PartnerFinalizationResult> finalizeSuccess(String orderId) async {
    final Object? raw = await _client.rpc(
      'phase5_finalize_partner_order_success',
      params: <String, dynamic>{
        'p_order_id': orderId.trim(),
        'p_processing_started_at': null,
      },
    );
    final Map<String, dynamic> row = _map(raw);
    return PartnerFinalizationResult(
      orderId: _string(row['order_id']),
      orderReference: _string(row['order_reference']),
      network: _string(row['network']),
      orderAmount: _integer(row['order_amount']),
      capacityBefore: _integer(row['capacity_before']),
      capacityAfter: _integer(row['capacity_after']),
      telecomMarginAmount: _integer(row['telecom_margin_amount']),
      cabinisteMarginAmount: _integer(row['cabiniste_margin_amount']),
      izytelMarginAmount: _integer(row['izytel_margin_amount']),
      customerFeeAmount: _integer(row['customer_fee_amount']),
      cabinisteSettlementAmount:
          _integer(row['cabiniste_settlement_amount']),
      izytelGrossGain: _integer(row['izytel_gross_gain']),
      idempotent: row['idempotent'] == true,
    );
  }

  Future<PartnerOrderSnapshot> _assignmentAction({
    required String orderId,
    required String action,
    String? reason,
  }) async {
    final Object? raw = await _client.rpc(
      'phase4_partner_action',
      params: <String, dynamic>{
        'p_order_id': orderId.trim(),
        'p_action': action,
        'p_reason': reason,
      },
    );
    return _orderFromRow(_map(raw));
  }

  Future<PartnerOrderSnapshot> _processingAction({
    required String orderId,
    required String action,
    String? reason,
    String? observation,
  }) async {
    final Object? raw = await _client.rpc(
      'phase4_partner_processing_action',
      params: <String, dynamic>{
        'p_order_id': orderId.trim(),
        'p_action': action,
        'p_reason': reason,
        'p_observation': observation,
      },
    );
    return _orderFromRow(_map(raw));
  }

  Future<PartnerAccountSnapshot> _requireOwnAccount() async {
    final PartnerAccountSnapshot? account = await fetchOwnAccount();
    if (account == null) {
      throw StateError('Partner account is not available.');
    }
    return account;
  }

  String _requireFirebaseUid() {
    final String uid = (_firebaseAuth.currentUser?.uid ?? '').trim();
    if (uid.isEmpty) {
      throw StateError('Firebase session is required.');
    }
    return uid;
  }

  PartnerAccountSnapshot _accountFromRows(
    Map<String, dynamic> account,
    Map<String, dynamic>? capacity,
  ) {
    return PartnerAccountSnapshot(
      id: _string(account['id']),
      partnerCode: _string(account['partner_code']),
      firebaseUid: _nullableString(account['firebase_uid']),
      displayName: _string(account['display_name']),
      phoneNumber: _string(account['phone_number']),
      city: _string(account['city']),
      status: _string(account['status']),
      availability: _string(account['availability']),
      authorizedNetworks: _stringList(account['authorized_networks']),
      activeNetworks: _stringList(account['active_networks']),
      orangeCapacity: _integer(capacity?['orange_capacity']),
      mtnCapacity: _integer(capacity?['mtn_capacity']),
      moovCapacity: _integer(capacity?['moov_capacity']),
    );
  }

  PartnerOrderSnapshot _orderFromRow(Map<String, dynamic> row) {
    return PartnerOrderSnapshot(
      orderId: _string(row['order_id']),
      orderReference: _string(row['order_reference']),
      network: _string(row['network']),
      amount: _integer(row['amount']),
      assignmentState: _string(row['assignment_state']),
      orderStatus: _string(row['order_status']),
      assignedPartnerId: _string(row['assigned_cabiniste_id']),
      assignedPartnerName: _string(row['assigned_cabiniste_name']),
      processingStartedAt: _dateTime(row['processing_started_at']),
      completedAt: _dateTime(row['completed_at']),
      failureReason: _nullableString(row['failure_reason']),
      observation: _nullableString(row['observation']),
      lastHoldReason: _nullableString(row['last_hold_reason']),
      updatedAt: _dateTime(row['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> _map(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw StateError('Invalid Supabase response.');
  }

  String _string(Object? value) => value?.toString().trim() ?? '';

  String? _nullableString(Object? value) {
    final String result = _string(value);
    return result.isEmpty ? null : result;
  }

  int _integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return List<String>.unmodifiable(
      value.map(_string).where((String item) => item.isNotEmpty),
    );
  }

  DateTime? _dateTime(Object? value) {
    if (value is DateTime) return value.toUtc();
    final String raw = _string(value);
    return raw.isEmpty ? null : DateTime.tryParse(raw)?.toUtc();
  }
}
