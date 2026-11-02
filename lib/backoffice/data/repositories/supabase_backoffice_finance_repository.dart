import 'package:cabine_flow/backoffice/domain/models/backoffice_finance_snapshot.dart';
import 'package:cabine_flow/backoffice/domain/repositories/backoffice_finance_repository.dart';
import 'package:cabine_flow/core/supabase/supabase_realtime_refetch.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/finances/domain/services/finance_operation_key.dart';
import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
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
        signals: const <SupabaseRealtimeSignal>[
          SupabaseRealtimeSignal(
            table: 'finance_change_feed',
            primaryKey: <String>['id'],
          ),
        ],
      );

  @override
  Future<BackofficeFinanceSnapshot> fetchSnapshot() async {
    final List<_FinanceReadResult> responses =
        await Future.wait<_FinanceReadResult>(<Future<_FinanceReadResult>>[
          _capture(_client.rpc('izytel_finance_snapshot')),
          _capture(
            _client.rpc(
              'izytel_admin_cabiniste_finance_snapshot',
              params: const <String, dynamic>{'p_partner_id': null},
            ),
          ),
        ]);
    final _FinanceReadResult core = responses[0];
    final _FinanceReadResult cabiniste = responses[1];
    if (core.error case final Object error) {
      IzyTelLog.backendError(
        'SupabaseBackofficeFinanceRepository.core',
        error,
        stackTrace: core.stackTrace,
      );
      Error.throwWithStackTrace(error, core.stackTrace ?? StackTrace.current);
    }
    final dynamic response = core.value;
    final Map<String, dynamic>? map = financeMap(response);
    if (map == null) {
      throw StateError('Le snapshot financier Supabase est invalide.');
    }
    final Map<String, dynamic> merged = Map<String, dynamic>.from(map);
    if (cabiniste.error case final Object error) {
      IzyTelLog.backendError(
        'SupabaseBackofficeFinanceRepository.cabiniste',
        error,
        stackTrace: cabiniste.stackTrace,
      );
      merged
        ..['cabiniste_finance'] = const <String, dynamic>{}
        ..['_partial_issue_code'] = BackendFailurePolicy.safeCode(error)
        ..['_partial_issue_kind'] = BackendFailurePolicy.classify(error).name;
    } else {
      final Map<String, dynamic>? cabinisteMap = financeMap(cabiniste.value);
      if (cabinisteMap == null) {
        merged
          ..['cabiniste_finance'] = const <String, dynamic>{}
          ..['_partial_issue_code'] = 'contract:cabiniste-snapshot'
          ..['_partial_issue_kind'] = BackendFailureKind.contract.name;
      } else {
        merged['cabiniste_finance'] = cabinisteMap;
      }
    }
    return BackofficeFinanceSnapshot.fromJson(merged);
  }

  Future<_FinanceReadResult> _capture(Future<dynamic> operation) async {
    try {
      return _FinanceReadResult(value: await operation);
    } catch (error, stackTrace) {
      return _FinanceReadResult(error: error, stackTrace: stackTrace);
    }
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

class _FinanceReadResult {
  const _FinanceReadResult({this.value, this.error, this.stackTrace});

  final dynamic value;
  final Object? error;
  final StackTrace? stackTrace;
}
