import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSupportRequestRepository implements SupportRequestRepository {
  SupabaseSupportRequestRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String tableName = 'support_requests';
  final SupabaseClient _client;
  @override
  Future<SupportRequest> create({
    required String orderId,
    required String orderReference,
    required SupportRequestType type,
    required String description,
  }) async {
    final String cleanedOrderId = orderId.trim();
    final String cleanedReference = orderReference.trim().toUpperCase();
    final String cleanedDescription = description.trim();
    if (cleanedOrderId.isEmpty || cleanedReference.length < 8) {
      throw ArgumentError('La commande associée est invalide.');
    }
    if (cleanedDescription.length > 1000) {
      throw ArgumentError('La description est trop longue.');
    }
    if (type == SupportRequestType.other && cleanedDescription.length < 3) {
      throw ArgumentError('Précisez le problème en quelques mots.');
    }

    final dynamic response = await _client.rpc(
      'izytel_create_support_request',
      params: <String, dynamic>{
        'p_order_id': cleanedOrderId,
        'p_order_reference': cleanedReference,
        'p_type': type.storageValue,
        'p_description': cleanedDescription,
      },
    );
    final Map<String, dynamic>? row = _firstRow(response);
    final SupportRequest? request = row == null ? null : _fromRow(row);
    if (request == null) {
      throw StateError('La demande a été créée mais sa lecture a échoué.');
    }
    return request;
  }

  @override
  Stream<List<SupportRequest>> watchForOrder({required String orderId}) {
    final String cleanedOrderId = orderId.trim();
    if (cleanedOrderId.isEmpty) {
      return Stream<List<SupportRequest>>.value(const <SupportRequest>[]);
    }
    return _watch(orderId: cleanedOrderId);
  }

  @override
  Stream<List<SupportRequest>> watchNewRequests() {
    return _watch(status: SupportRequestStatus.newRequest.storageValue);
  }

  @override
  Stream<List<SupportRequest>> watchAllRequests() => _watch();

  Stream<List<SupportRequest>> _watch({String? orderId, String? status}) {
    Stream<List<Map<String, dynamic>>> rowsStream;
    if (orderId != null) {
      rowsStream = _client
          .from(tableName)
          .stream(primaryKey: const <String>['id'])
          .eq('order_id', orderId);
    } else if (status != null) {
      rowsStream = _client
          .from(tableName)
          .stream(primaryKey: const <String>['id'])
          .eq('status', status);
    } else {
      rowsStream = _client
          .from(tableName)
          .stream(primaryKey: const <String>['id']);
    }

    return rowsStream.map((List<Map<String, dynamic>> rows) {
      final List<SupportRequest> requests = rows
          .map(_fromRow)
          .whereType<SupportRequest>()
          .toList(growable: false)
        ..sort(
          (SupportRequest a, SupportRequest b) =>
              b.updatedAt.compareTo(a.updatedAt),
        );
      return List<SupportRequest>.unmodifiable(requests);
    });
  }

  @override
  Future<void> takeInCharge({
    required String requestId,
    required String staffId,
    required String staffName,
  }) {
    return _rpcVoid(
      'izytel_take_support_request',
      <String, dynamic>{'p_request_id': requestId.trim()},
    );
  }

  @override
  Future<void> resolve({
    required String requestId,
    required String staffId,
    required String staffName,
    required String resolutionNote,
  }) {
    final String note = resolutionNote.trim();
    if (note.length < 3 || note.length > 1000) {
      throw ArgumentError('Ajoutez une note de résolution valide.');
    }
    return _rpcVoid(
      'izytel_resolve_support_request',
      <String, dynamic>{
        'p_request_id': requestId.trim(),
        'p_resolution_note': note,
      },
    );
  }

  @override
  Future<void> markCustomerNotified({
    required String requestId,
    required String staffId,
    required String staffName,
  }) {
    return _rpcVoid(
      'izytel_mark_support_customer_notified',
      <String, dynamic>{'p_request_id': requestId.trim()},
    );
  }

  @override
  Future<void> close({
    required String requestId,
    required String staffId,
    required String staffName,
  }) {
    return _rpcVoid(
      'izytel_close_support_request',
      <String, dynamic>{'p_request_id': requestId.trim()},
    );
  }

  Future<void> _rpcVoid(String function, Map<String, dynamic> params) async {
    await _client.rpc(function, params: params);
  }

  SupportRequest? _fromRow(Map<String, dynamic> row) {
    final String id = _string(row['id']);
    final String orderId = _string(row['order_id']);
    final String orderReference = _string(row['order_reference']);
    final String customerUid = _string(row['customer_auth_uid']);
    final DateTime? createdAt = _date(row['created_at']);
    final DateTime? updatedAt = _date(row['updated_at']);
    if (id.isEmpty ||
        orderId.isEmpty ||
        orderReference.isEmpty ||
        customerUid.isEmpty ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    return SupportRequest(
      id: id,
      orderId: orderId,
      orderReference: orderReference,
      customerAuthUid: customerUid,
      type: SupportRequestTypeX.fromStorage(_string(row['type'])),
      description: _string(row['description']),
      status: SupportRequestStatusX.fromStorage(_string(row['status'])),
      createdAt: createdAt,
      updatedAt: updatedAt,
      assignedTo: _nullable(row['assigned_to']),
      assignedToName: _nullable(row['assigned_to_name']),
      inProgressAt: _date(row['in_progress_at']),
      resolutionNote: _nullable(row['resolution_note']),
      resolvedAt: _date(row['resolved_at']),
      resolvedBy: _nullable(row['resolved_by']),
      resolvedByName: _nullable(row['resolved_by_name']),
      customerNotifiedAt: _date(row['customer_notified_at']),
      customerNotifiedBy: _nullable(row['customer_notified_by']),
      customerNotifiedByName: _nullable(row['customer_notified_by_name']),
      notificationChannel: _nullable(row['notification_channel']),
      closedAt: _date(row['closed_at']),
      closedBy: _nullable(row['closed_by']),
      closedByName: _nullable(row['closed_by_name']),
    );
  }

  Map<String, dynamic>? _firstRow(dynamic response) {
    if (response is Map<String, dynamic>) return response;
    if (response is List && response.isNotEmpty) {
      final dynamic first = response.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    if (response is Map) return Map<String, dynamic>.from(response);
    return null;
  }

  String _string(Object? value) => value is String ? value.trim() : '';

  String? _nullable(Object? value) {
    final String text = _string(value);
    return text.isEmpty ? null : text;
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim())?.toLocal();
    }
    return null;
  }
}
