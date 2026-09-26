import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCustomerOrderStatusRepository {
  SupabaseCustomerOrderStatusRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const Duration pollInterval = Duration(seconds: 3);

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchStatus({
    required String orderId,
    required String reference,
  }) async {
    final Object? raw = await _client.rpc(
      'izytel_wc2_customer_order_status',
      params: <String, dynamic>{
        'p_order_id': orderId.trim(),
        'p_reference': reference.trim(),
      },
    );
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw StateError('Statut operationnel Supabase invalide.');
  }

  Future<CustomerOrderReceipt> overlay(CustomerOrderReceipt receipt) async {
    final Map<String, dynamic>? row = await fetchStatus(
      orderId: receipt.id,
      reference: receipt.reference,
    );
    if (row == null) return receipt;
    return overlayRow(receipt, row);
  }

  Stream<CustomerOrderReceipt> watch(CustomerOrderReceipt receipt) async* {
    CustomerOrderReceipt lastKnown = receipt;
    int failures = 0;
    while (true) {
      try {
        lastKnown = await overlay(lastKnown);
        failures = 0;
        yield lastKnown;
        await Future<void>.delayed(pollInterval);
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'CustomerOrder.supabase-status',
          error,
          stackTrace: stackTrace,
        );
        if (!BackendFailurePolicy.canRetryRead(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        yield lastKnown;
        await Future<void>.delayed(
          BackendFailurePolicy.retryDelay(
            baseDelay: pollInterval,
            consecutiveFailures: failures++,
          ),
        );
      }
    }
  }

  CustomerOrderReceipt overlayRow(
    CustomerOrderReceipt receipt,
    Map<String, dynamic> row,
  ) {
    final QueueOrderStatus? status = _orderStatus(row['order_status']);
    final OrderPaymentStatus? paymentStatus = _paymentStatus(
      row['payment_status'],
    );
    final String failureReason = _string(row['failure_reason']);
    return receipt.copyWith(
      status: status,
      paymentStatus: paymentStatus,
      processingStartedAt: _date(row['processing_started_at']),
      completedAt: _date(row['completed_at']),
      failureMessage: failureReason.isEmpty
          ? null
          : _failureMessage(failureReason),
      clearFailureMessage: failureReason.isEmpty,
    );
  }

  QueueOrderStatus? _orderStatus(Object? value) {
    final String token = _string(value);
    for (final QueueOrderStatus status in QueueOrderStatus.values) {
      if (status.name == token) return status;
    }
    return null;
  }

  OrderPaymentStatus? _paymentStatus(Object? value) {
    final String token = _string(value);
    for (final OrderPaymentStatus status in OrderPaymentStatus.values) {
      if (status.name == token) return status;
    }
    return null;
  }

  String _failureMessage(String reason) {
    switch (reason) {
      case 'incorrectNumber':
        return 'Le numero beneficiaire doit etre verifie.';
      case 'networkUnavailable':
        return 'Le reseau etait temporairement indisponible.';
      case 'offerUnavailable':
        return 'L’offre demandee etait indisponible.';
      case 'insufficientBalance':
        return 'Le traitement n’a pas pu etre finalise.';
      case 'incorrectPayment':
        return 'Le paiement doit etre verifie.';
      case 'technicalError':
      case 'other':
      default:
        return 'La commande n’a pas pu etre finalisee. Contacte le support si necessaire.';
    }
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim())?.toLocal();
    }
    return null;
  }

  String _string(Object? value) => value?.toString().trim() ?? '';
}
