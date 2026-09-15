import 'dart:async';

import 'package:cabine_flow/backoffice/domain/models/backoffice_finance_snapshot.dart';
import 'package:cabine_flow/backoffice/domain/repositories/backoffice_finance_repository.dart';
import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBackofficeFinanceRepository implements BackofficeFinanceRepository {
  SupabaseBackofficeFinanceRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Stream<BackofficeFinanceSnapshot> watchSnapshot() async* {
    BackofficeFinanceSnapshot last = await fetchSnapshot();
    yield last;

    try {
      final String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
      await _client.realtime.setAuth(token);
      final Stream<List<Map<String, dynamic>>> feed = _client
          .from('finance_change_feed')
          .stream(primaryKey: const <String>['id']);
      int? lastRevision;
      await for (final List<Map<String, dynamic>> rows in feed) {
        final int revision = rows.isEmpty ? -1 : financeInt(rows.first['revision']);
        if (lastRevision == revision) {
          continue;
        }
        lastRevision = revision;
        last = await fetchSnapshot();
        yield last;
      }
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'SupabaseBackofficeFinanceRepository.Realtime',
        error,
        stackTrace: stackTrace,
      );
      // Le snapshot REST déjà affiché reste valide. L'utilisateur peut aussi
      // forcer une actualisation depuis la page financière.
    }
  }

  @override
  Future<BackofficeFinanceSnapshot> fetchSnapshot() async {
    final dynamic response = await _client.rpc('izytel_finance_snapshot');
    final Map<String, dynamic>? map = financeMap(response);
    if (map == null) {
      throw StateError('Le snapshot financier Supabase est invalide.');
    }
    return BackofficeFinanceSnapshot.fromJson(map);
  }

  @override
  Future<void> setWaveOpening({required int amount, String? note}) async {
    await _client.rpc('izytel_finance_set_wave_opening', params: <String, dynamic>{
      'p_amount': amount,
      'p_note': _nullable(note),
    });
  }

  @override
  Future<String> saveSupplier({
    String? supplierId,
    required String name,
    required String phoneNumber,
    String? note,
  }) async {
    final dynamic response = await _client.rpc(
      'izytel_finance_save_supplier',
      params: <String, dynamic>{
        'p_supplier_id': _nullable(supplierId),
        'p_name': name.trim(),
        'p_phone_number': phoneNumber.trim(),
        'p_note': _nullable(note),
      },
    );
    return _stringResult(response);
  }

  @override
  Future<void> setSupplierActive({required String supplierId, required bool isActive}) async {
    await _client.rpc(
      'izytel_finance_set_supplier_active',
      params: <String, dynamic>{'p_supplier_id': supplierId, 'p_is_active': isActive},
    );
  }

  @override
  Future<void> deleteSupplier(String supplierId) async {
    await _client.rpc('izytel_finance_delete_supplier', params: <String, dynamic>{
      'p_supplier_id': supplierId,
    });
  }

  @override
  Future<String> recordSupplierRecharge({
    required String supplierId,
    required String agentId,
    required String agentName,
    required String network,
    required int principal,
    required int bonus,
    required int amountOwed,
    String? note,
    required String staffName,
  }) async {
    final dynamic response = await _client.rpc(
      'phase5_record_supplier_recharge',
      params: <String, dynamic>{
        'p_supplier_id': supplierId,
        'p_agent_id': agentId,
        'p_agent_name': agentName,
        'p_network': network,
        'p_principal': principal,
        'p_bonus': bonus,
        'p_amount_owed': amountOwed,
        'p_note': _nullable(note),
        'p_staff_name': staffName,
        'p_legacy_id': null,
        'p_operation_key': 'bo5-recharge-${DateTime.now().microsecondsSinceEpoch}',
      },
    );
    return _stringResult(response);
  }

  @override
  Future<String> recordSupplierPayment({
    required String supplierId,
    required int amount,
    required String channel,
    required String reference,
    String? note,
    required String staffName,
  }) async {
    final dynamic response = await _client.rpc(
      'phase5_record_supplier_payment',
      params: <String, dynamic>{
        'p_supplier_id': supplierId,
        'p_amount': amount,
        'p_channel': channel,
        'p_reference': reference.trim(),
        'p_note': _nullable(note),
        'p_staff_name': staffName,
        'p_legacy_id': null,
        'p_operation_key': 'bo5-supplier-payment-${DateTime.now().microsecondsSinceEpoch}',
      },
    );
    return _stringResult(response);
  }

  @override
  Future<String> recordCommissionPayout({
    required String agentId,
    required String agentName,
    required int amount,
    required String reference,
    String? note,
    required String staffName,
  }) async {
    final dynamic response = await _client.rpc(
      'phase5_record_commission_payout',
      params: <String, dynamic>{
        'p_agent_id': agentId,
        'p_agent_name': agentName,
        'p_amount': amount,
        'p_reference': reference.trim(),
        'p_staff_name': staffName,
        'p_note': _nullable(note),
      },
    );
    return _stringResult(response);
  }

  @override
  Future<String> authorizeCreditOrder({
    required QueueOrder order,
    String? note,
  }) async {
    final dynamic response = await _client.rpc(
      'izytel_finance_authorize_credit_order',
      params: <String, dynamic>{
        'p_payload': <String, dynamic>{
          'order_id': order.id,
          'order_reference': order.reference,
          'network': order.network.name,
          'amount': order.amount,
          'created_at': order.createdAt.toUtc().toIso8601String(),
          'source': order.source.name,
          'customer_auth_uid': _nullable(order.customerAuthUid),
          'client_name': order.clientName,
          'client_whatsapp_phone': order.clientWhatsappPhone,
          'beneficiary_phone': order.beneficiaryPhone,
          'operation_type': order.operationType.name,
          'offer_label': order.offerLabel,
          'original_whatsapp_message': _nullable(order.originalWhatsappMessage),
          'internal_notes': _nullable(order.internalNotes),
          'original_order_status': order.status.name,
          'original_payment_status': order.paymentStatus.name,
          'original_payment_reference': _nullable(order.paymentReference),
        },
        'p_note': _nullable(note),
      },
    );
    return _stringResult(response);
  }

  @override
  Future<String> createCredit({
    String? creditId,
    required String orderId,
    required String orderReference,
    required String clientName,
    required String clientWhatsappPhone,
    required int amount,
    String? note,
  }) async {
    final dynamic response = await _client.rpc(
      'izytel_finance_create_credit',
      params: <String, dynamic>{
        'p_credit_id': _nullable(creditId),
        'p_order_id': orderId,
        'p_order_reference': orderReference,
        'p_client_name': clientName.trim(),
        'p_client_whatsapp_phone': clientWhatsappPhone.trim(),
        'p_amount': amount,
        'p_note': _nullable(note),
      },
    );
    return _stringResult(response);
  }

  @override
  Future<String> settleCredit({
    required String creditId,
    required int amount,
    required String channel,
    required String reference,
    String? note,
  }) async {
    final dynamic response = await _client.rpc(
      'izytel_finance_settle_credit',
      params: <String, dynamic>{
        'p_credit_id': creditId,
        'p_amount': amount,
        'p_channel': channel,
        'p_reference': reference.trim(),
        'p_note': _nullable(note),
      },
    );
    return _stringResult(response);
  }

  @override
  Future<String> recordExpense({
    required String category,
    required int amount,
    required String description,
    required String channel,
    String? reference,
  }) async {
    final dynamic response = await _client.rpc(
      'izytel_finance_record_expense',
      params: <String, dynamic>{
        'p_category': category,
        'p_amount': amount,
        'p_description': description.trim(),
        'p_channel': channel,
        'p_reference': _nullable(reference),
      },
    );
    return _stringResult(response);
  }

  @override
  Future<String> createClosing(Map<String, dynamic> payload) async {
    final dynamic response = await _client.rpc(
      'izytel_finance_create_closing',
      params: <String, dynamic>{'p_payload': payload},
    );
    return _stringResult(response);
  }

  String _stringResult(dynamic response) {
    if (response == null) {
      return '';
    }
    if (response is String) {
      return response;
    }
    if (response is num) {
      return response.toString();
    }
    if (response is Map) {
      for (final String key in const <String>['id', 'result', 'value']) {
        final Object? value = response[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
    }
    return response.toString();
  }

  String? _nullable(String? value) {
    final String cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }
}
