import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRefundRepository implements RefundRepository {
  SupabaseRefundRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String tableName = 'refunds';
  final SupabaseClient _client;
  @override
  Stream<List<RefundCase>> watchAll() => _watch();

  @override
  Stream<RefundCase?> watchForOrder({required String orderId}) async* {
    final String cleanedOrderId = orderId.trim();
    if (cleanedOrderId.isEmpty) {
      yield null;
      return;
    }
    await for (final List<RefundCase> refunds in _watch(orderId: cleanedOrderId)) {
      yield refunds.isEmpty ? null : refunds.first;
    }
  }

  Stream<List<RefundCase>> _watch({String? orderId}) async* {
    // La Data API reste la source fiable de premier affichage. Realtime est un
    // accélérateur : s'il refuse momentanément le JWT Firebase, on conserve les
    // données REST au lieu de mettre tout le module en erreur.
    yield await _fetch(orderId: orderId);

    try {
      final String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null || token.trim().isEmpty) return;
      await _client.realtime.setAuth(token);

      dynamic realtimeQuery = _client
          .from(tableName)
          .stream(primaryKey: const <String>['order_id']);
      if (orderId != null) {
        realtimeQuery = realtimeQuery.eq('order_id', orderId);
      }
      final Stream<List<Map<String, dynamic>>> rowsStream = realtimeQuery;

      await for (final List<Map<String, dynamic>> rows in rowsStream) {
        yield _mapRows(rows);
      }
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'SupabaseRefundRepository.Realtime',
        error,
        stackTrace: stackTrace,
      );
      // Important : ne pas propager l'erreur Realtime au StreamBuilder. Le
      // dernier instantané REST reste utilisable et les actions RPC continuent.
    }
  }

  Future<List<RefundCase>> _fetch({String? orderId}) async {
    dynamic query = _client.from(tableName).select();
    if (orderId != null) {
      query = query.eq('order_id', orderId);
    }
    final dynamic response = await query;
    final List<Map<String, dynamic>> rows = response is List
        ? response
              .whereType<Map>()
              .map((Map row) => Map<String, dynamic>.from(row))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    return _mapRows(rows);
  }

  List<RefundCase> _mapRows(List<Map<String, dynamic>> rows) {
    final List<RefundCase> refunds = rows
        .map(_fromRow)
        .whereType<RefundCase>()
        .toList(growable: false)
      ..sort(
        (RefundCase a, RefundCase b) => b.updatedAt.compareTo(a.updatedAt),
      );
    return List<RefundCase>.unmodifiable(refunds);
  }

  @override
  Future<RefundCase> create({
    required RefundCreationRequest request,
    required String staffId,
    required String staffName,
  }) async {
    final String orderId = request.orderId.trim();
    final String reference = request.orderReference.trim().toUpperCase();
    final String note = request.reasonNote.trim();
    if (orderId.isEmpty || reference.isEmpty) {
      throw ArgumentError('La commande associée est invalide.');
    }
    if (request.amount <= 0 || request.amount > request.originalAmount) {
      throw ArgumentError('Le montant à rembourser est invalide.');
    }
    if (note.length > 500 ||
        (request.reason == RefundReason.other && note.length < 3)) {
      throw ArgumentError('Le motif du remboursement est invalide.');
    }

    final dynamic response = await _client.rpc(
      'izytel_create_refund',
      params: <String, dynamic>{
        'p_order_id': orderId,
        'p_order_reference': reference,
        'p_origin': request.origin.storageValue,
        'p_support_request_id': request.supportRequestId.trim(),
        'p_amount': request.amount,
        'p_reason': request.reason.storageValue,
        'p_reason_note': note,
      },
    );
    final Map<String, dynamic>? row = _firstRow(response);
    final RefundCase? refund = row == null ? null : _fromRow(row);
    if (refund == null) {
      throw StateError('Le remboursement a été créé mais sa lecture a échoué.');
    }
    return refund;
  }

  @override
  Future<void> approve({
    required String orderId,
    required String staffId,
    required String staffName,
  }) => _rpcVoid(
    'izytel_approve_refund',
    <String, dynamic>{'p_order_id': orderId.trim()},
  );

  @override
  Future<void> reject({
    required String orderId,
    required String staffId,
    required String staffName,
    required String reason,
  }) {
    final String cleanedReason = reason.trim();
    if (cleanedReason.length < 3 || cleanedReason.length > 500) {
      throw ArgumentError('Précisez pourquoi le remboursement est rejeté.');
    }
    return _rpcVoid(
      'izytel_reject_refund',
      <String, dynamic>{
        'p_order_id': orderId.trim(),
        'p_reason': cleanedReason,
      },
    );
  }

  @override
  Future<void> markRefunded({
    required String orderId,
    required String staffId,
    required String staffName,
    required String refundReference,
  }) {
    final String reference = refundReference.trim();
    if (reference.length < 3 || reference.length > 120) {
      throw ArgumentError('Saisissez la référence du remboursement Wave.');
    }
    return _rpcVoid(
      'izytel_mark_refund_paid',
      <String, dynamic>{
        'p_order_id': orderId.trim(),
        'p_refund_reference': reference,
      },
    );
  }

  @override
  Future<void> markCustomerNotified({
    required String orderId,
    required String staffId,
    required String staffName,
  }) => _rpcVoid(
    'izytel_mark_refund_customer_notified',
    <String, dynamic>{'p_order_id': orderId.trim()},
  );

  @override
  Future<void> reconcile({
    required String orderId,
    required String staffId,
    required String staffName,
  }) => _rpcVoid(
    'izytel_reconcile_refund',
    <String, dynamic>{'p_order_id': orderId.trim()},
  );

  Future<void> _rpcVoid(String function, Map<String, dynamic> params) async {
    await _client.rpc(function, params: params);
  }

  RefundCase? _fromRow(Map<String, dynamic> row) {
    final String orderId = _string(row['order_id']);
    final String orderReference = _string(row['order_reference']);
    final String clientName = _string(row['client_name']);
    final int? originalAmount = _int(row['original_amount']);
    final int? amount = _int(row['amount']);
    final DateTime? requestedAt = _date(row['requested_at']);
    final DateTime? updatedAt = _date(row['updated_at']);
    final String requestedBy = _string(row['requested_by']);
    final String requestedByName = _string(row['requested_by_name']);
    if (orderId.isEmpty ||
        orderReference.isEmpty ||
        clientName.isEmpty ||
        originalAmount == null ||
        amount == null ||
        requestedAt == null ||
        updatedAt == null ||
        requestedBy.isEmpty ||
        requestedByName.isEmpty) {
      return null;
    }

    return RefundCase(
      id: orderId,
      orderId: orderId,
      orderReference: orderReference,
      origin: RefundOriginX.fromStorage(_string(row['origin'])),
      supportRequestId: _string(row['support_request_id']),
      supportRequestType: _string(row['support_request_type']),
      supportRequestDescription: _string(row['support_request_description']),
      customerAuthUid: _nullable(row['customer_auth_uid']),
      clientName: clientName,
      clientWhatsappPhone: _string(row['client_whatsapp_phone']),
      originalAmount: originalAmount,
      amount: amount,
      reason: RefundReasonX.fromStorage(_string(row['reason'])),
      reasonNote: _string(row['reason_note']),
      paymentChannel: _string(row['payment_channel'], fallback: 'wave'),
      originalPaymentReference: _nullable(row['original_payment_reference']),
      status: RefundStatusX.fromStorage(_string(row['status'])),
      requestedAt: requestedAt,
      requestedBy: requestedBy,
      requestedByName: requestedByName,
      updatedAt: updatedAt,
      approvedAt: _date(row['approved_at']),
      approvedBy: _nullable(row['approved_by']),
      approvedByName: _nullable(row['approved_by_name']),
      rejectedAt: _date(row['rejected_at']),
      rejectedBy: _nullable(row['rejected_by']),
      rejectedByName: _nullable(row['rejected_by_name']),
      rejectionReason: _nullable(row['rejection_reason']),
      refundReference: _nullable(row['refund_reference']),
      refundedAt: _date(row['refunded_at']),
      refundedBy: _nullable(row['refunded_by']),
      refundedByName: _nullable(row['refunded_by_name']),
      customerNotifiedAt: _date(row['customer_notified_at']),
      customerNotifiedBy: _nullable(row['customer_notified_by']),
      customerNotifiedByName: _nullable(row['customer_notified_by_name']),
      notificationChannel: _nullable(row['notification_channel']),
      reconciledAt: _date(row['reconciled_at']),
      reconciledBy: _nullable(row['reconciled_by']),
      reconciledByName: _nullable(row['reconciled_by_name']),
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

  String _string(Object? value, {String fallback = ''}) {
    if (value is! String) return fallback;
    final String text = value.trim();
    return text.isEmpty ? fallback : text;
  }

  String? _nullable(Object? value) {
    final String text = _string(value);
    return text.isEmpty ? null : text;
  }

  int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim())?.toLocal();
    }
    return null;
  }
}
