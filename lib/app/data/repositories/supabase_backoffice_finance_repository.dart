import 'package:cabine_flow/app/domain/entities/backoffice/backoffice_finance_snapshot.dart';
import 'package:cabine_flow/app/domain/repositories/backoffice_finance_repository.dart';
import 'package:cabine_flow/app/data/sources/supabase_realtime_refetch.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/domain/policies/finance/finance_operation_key.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBackofficeFinanceRepository
    implements BackofficeFinanceRepository {
  SupabaseBackofficeFinanceRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Stream<BackofficeFinanceSnapshot> watchSnapshot() =>
      SupabaseRealtimeRefetch.watch<BackofficeFinanceSnapshot>(
        client: _client,
        fetch: fetchSnapshot,
        label: 'SupabaseBackofficeFinanceRepository.snapshot',
        independentPolling: true,
        fallbackInterval: const Duration(seconds: 15),
        signals: const <SupabaseRealtimeSignal>[
          SupabaseRealtimeSignal(
            table: 'finance_change_feed',
            primaryKey: <String>['id'],
          ),
        ],
      );

  @override
  Future<BackofficeFinanceSnapshot> fetchSnapshot() async {
    // Core balances and Cabiniste liabilities share one database snapshot.
    // A failed read cannot silently turn a missing liability into zero.
    final dynamic response = await _client.rpc('izytel_finance_snapshot');
    final Map<String, dynamic>? map = financeMap(response);
    if (map == null) {
      throw StateError('Le snapshot financier Supabase est invalide.');
    }
    if (financeMap(map['cabiniste_finance']) == null ||
        financeMap(map['global_totals']) == null ||
        financeMap(map['day_totals']) == null) {
      throw StateError('Le snapshot financier consolidé est incomplet.');
    }
    return BackofficeFinanceSnapshot.fromJson(map);
  }

  @override
  Future<Map<String, dynamic>> fetchPeriodHistory({
    required String module,
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _client.rpc(
      'izytel_bo75_finance_period_history',
      params: {
        'p_module': module,
        'p_start': start.toUtc().toIso8601String(),
        'p_end': end.toUtc().toIso8601String(),
      },
    );
    final map = financeMap(response);
    if (map == null || financeMap(map['totals']) == null) {
      throw StateError('Historique financier incomplet.');
    }
    return map;
  }

  @override
  Future<void> setWaveOpening({required int amount, String? note}) async {
    await _client.rpc(
      'izytel_finance_set_wave_opening',
      params: <String, dynamic>{'p_amount': amount, 'p_note': _nullable(note)},
    );
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
  Future<void> setSupplierActive({
    required String supplierId,
    required bool isActive,
  }) async {
    await _client.rpc(
      'izytel_finance_set_supplier_active',
      params: <String, dynamic>{
        'p_supplier_id': supplierId,
        'p_is_active': isActive,
      },
    );
  }

  @override
  Future<void> deleteSupplier(String supplierId) async {
    await _client.rpc(
      'izytel_finance_delete_supplier',
      params: <String, dynamic>{'p_supplier_id': supplierId},
    );
  }

  @override
  Future<String> recordSupplierRecharge({
    String? operationKey,
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
        'p_operation_key': operationKey ?? createFinanceOperationKey(),
      },
    );
    return _stringResult(response);
  }

  @override
  Future<String> recordSupplierPayment({
    String? operationKey,
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
        'p_operation_key': operationKey ?? createFinanceOperationKey(),
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
  Future<Map<String, dynamic>> recordCabinistePayout({
    required String partnerId,
    required int amount,
    required String channel,
    required String reference,
    String? note,
    String? periodId,
  }) async {
    final dynamic response = await _client.rpc(
      'izytel_admin_record_cabiniste_payout',
      params: <String, dynamic>{
        'p_partner_id': partnerId,
        'p_amount': amount,
        'p_payment_channel': channel,
        'p_payment_reference': reference.trim(),
        'p_note': _nullable(note),
        'p_period_id': _nullable(periodId),
      },
    );
    final Map<String, dynamic>? map = financeMap(response);
    if (map == null) {
      throw StateError(
        'Le règlement Cabiniste renvoyé par Supabase est invalide.',
      );
    }
    return map;
  }

  @override
  Future<Map<String, dynamic>> fetchCabinisteFinanceHistory({
    required String partnerId,
    int limit = 50,
  }) async {
    final dynamic response = await _client.rpc(
      'izytel_admin_cabiniste_finance_history',
      params: <String, dynamic>{
        'p_partner_id': partnerId,
        'p_limit': limit.clamp(1, 200),
      },
    );
    final Map<String, dynamic>? map = financeMap(response);
    if (map == null) {
      throw StateError('L’historique financier Cabiniste est invalide.');
    }
    return map;
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
    String? operationKey,
    required String category,
    required int amount,
    required String description,
    required String channel,
    String? reference,
  }) async {
    final dynamic response = await _client.rpc(
      'izytel_finance_record_expense_once',
      params: <String, dynamic>{
        'p_category': category,
        'p_operation_key': operationKey ?? createFinanceOperationKey(),
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
