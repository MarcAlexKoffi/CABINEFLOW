import 'dart:async';

import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/models/network_finance_models.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registre financier Phase 5 partagé entre Agent, Manager et Admin web.
///
/// Les écritures sensibles sont exposées par des RPC idempotentes. Les tables
/// ne sont jamais écrites directement depuis Flutter. Tant que les règles
/// Firestore historiques imposent encore la transaction de succès/recharge,
/// ce registre reçoit un miroir réconciliable, puis deviendra la source unique
/// lorsque le domaine Commandes post-handoff sera migré.
class SupabasePhase5FinanceRepository {
  SupabasePhase5FinanceRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const Duration pollInterval = Duration(seconds: 3);
  static const int agentHistoryLimit = 250;
  static const int staffHistoryLimit = 2000;

  final SupabaseClient _client;

  Future<void> ensureCapacitySeed({
    required String agentId,
    required String agentName,
    required int orangeCapacity,
    required int mtnCapacity,
    required int moovCapacity,
  }) async {
    await _client.rpc('phase5_ensure_capacity_seed', params: <String, dynamic>{
      'p_agent_id': agentId.trim(),
      'p_agent_name': _safeName(agentName),
      'p_orange': orangeCapacity,
      'p_mtn': mtnCapacity,
      'p_moov': moovCapacity,
    });
  }

  Future<void> finalizeOrderSuccess({
    required QueueOrder order,
    required String agentId,
    required String agentName,
  }) async {
    if (order.assignedAgentId != null && order.assignedAgentId != agentId) {
      throw StateError('Cette commande appartient à un autre agent.');
    }
    await _client.rpc('phase5_finalize_order_success', params: <String, dynamic>{
      'p_order_id': order.id,
      'p_agent_name': _safeName(agentName),
      'p_processing_started_at': order.takenAt?.toUtc().toIso8601String(),
    });
  }

  Future<void> markFirestoreSuccessMirrored(String orderId) async {
    await _client.rpc(
      'phase5_mark_firestore_success_mirrored',
      params: <String, dynamic>{'p_order_id': orderId.trim()},
    );
  }

  Future<void> mirrorOrderPayment(QueueOrder order) {
    return mirrorOrderPaymentSnapshot(
      orderId: order.id,
      orderReference: order.reference,
      amount: order.amount,
      status: order.paymentStatus.name,
      paymentReference: order.paymentReference,
      payerName: order.paymentPayerName,
      channel: order.paymentStatus == OrderPaymentStatus.credit ? 'credit' : 'wave',
      paidAt: order.paidAt,
      confirmedAt: order.paymentConfirmedAt,
      source: order.source.name,
    );
  }

  Future<void> mirrorOrderPaymentSnapshot({
    required String orderId,
    required String orderReference,
    required int amount,
    required String status,
    String? paymentReference,
    String? payerName,
    String? channel,
    DateTime? paidAt,
    DateTime? confirmedAt,
    String source = 'operatorApp',
  }) async {
    if (status != 'confirmed' && status != 'credit') return;
    await _client.rpc('phase5_upsert_order_payment', params: <String, dynamic>{
      'p_order_id': orderId.trim(),
      'p_order_reference': orderReference.trim(),
      'p_amount': amount,
      'p_status': status,
      'p_reference': paymentReference,
      'p_payer_name': payerName,
      'p_channel': channel ?? (status == 'credit' ? 'credit' : 'wave'),
      'p_paid_at': paidAt?.toUtc().toIso8601String(),
      'p_confirmed_at': confirmedAt?.toUtc().toIso8601String(),
      'p_source': source,
    });
  }

  Future<void> mirrorSupplierRecharge(SupplierRecharge recharge) async {
    await _client.rpc('phase5_record_supplier_recharge', params: <String, dynamic>{
      'p_supplier_id': recharge.supplierId,
      'p_agent_id': recharge.agentId,
      'p_agent_name': _safeName(recharge.agentName),
      'p_network': recharge.network.firestoreValue,
      'p_principal': recharge.principalAmount,
      'p_bonus': recharge.bonusAmount,
      'p_amount_owed': recharge.amountOwed,
      'p_note': recharge.note,
      'p_staff_name': _safeName(recharge.createdByName, fallback: 'Administration'),
      'p_legacy_id': recharge.id,
      'p_operation_key': 'legacy:${recharge.id}',
    });
  }

  Future<void> mirrorSupplierPayment(SupplierPayment payment) async {
    await _client.rpc('phase5_record_supplier_payment', params: <String, dynamic>{
      'p_supplier_id': payment.supplierId,
      'p_amount': payment.amount,
      'p_channel': payment.channel.storageValue,
      'p_reference': payment.reference,
      'p_note': payment.note,
      'p_staff_name': _safeName(payment.createdByName, fallback: 'Administration'),
      'p_legacy_id': payment.id,
      'p_operation_key': 'legacy:${payment.id}',
    });
  }

  Future<void> reconcileCapacitySnapshot(Map<String, dynamic> row) async {
    await _client.rpc(
      'phase5_reconcile_capacity_snapshot',
      params: <String, dynamic>{'p_row': row},
    );
  }

  Future<int> importRechargeHistoryBatch(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return 0;
    final Object? result = await _client.rpc(
      'phase5_import_recharge_history_batch',
      params: <String, dynamic>{'p_rows': rows},
    );
    return result is num ? result.toInt() : int.tryParse('$result') ?? 0;
  }

  Future<int> importSuccessFinalizations(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return 0;
    final Object? result = await _client.rpc(
      'phase5_import_success_finalizations',
      params: <String, dynamic>{'p_rows': rows},
    );
    return result is num ? result.toInt() : int.tryParse('$result') ?? 0;
  }

  Future<int> importLegacyBatch({
    required String kind,
    required List<Map<String, dynamic>> rows,
  }) async {
    if (rows.isEmpty) return 0;
    final Object? result = await _client.rpc(
      'phase5_import_legacy_batch',
      params: <String, dynamic>{'p_kind': kind, 'p_rows': rows},
    );
    return result is num ? result.toInt() : int.tryParse('$result') ?? 0;
  }

  Future<AgentCommissionSummary> fetchAgentCommissionSummary() async {
    final List<Map<String, dynamic>> rows = await _client.rpc(
      'phase5_agent_commission_summary',
    );
    if (rows.isEmpty) {
      return const AgentCommissionSummary(
        earnedTotal: 0,
        paidTotal: 0,
        balance: 0,
        earnedTransactions: 0,
        earnedThisMonth: 0,
      );
    }
    final Map<String, dynamic> row = rows.first;
    return AgentCommissionSummary(
      earnedTotal: _int(row['earned_total']),
      paidTotal: _int(row['paid_total']),
      balance: _int(row['balance']),
      earnedTransactions: _int(row['earned_transactions']),
      earnedThisMonth: _int(row['earned_this_month']),
    );
  }

  Stream<AgentCommissionSummary> watchAgentCommissionSummary() async* {
    AgentCommissionSummary? lastSuccessful;
    while (true) {
      try {
        final AgentCommissionSummary value = await fetchAgentCommissionSummary();
        lastSuccessful = value;
        yield value;
      } catch (error, stackTrace) {
        debugPrint('[Phase5][commission-summary] $error');
        debugPrintStack(stackTrace: stackTrace);
        if (lastSuccessful == null) rethrow;
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<void> mirrorCommissionPayout(CommissionPayout payout) async {
    await _client.rpc(
      'phase5_mirror_legacy_commission_payout',
      params: <String, dynamic>{
        'p_row': <String, dynamic>{
          'source_firestore_id': payout.id,
          'agent_id': payout.agentId,
          'agent_name': _safeName(payout.agentName),
          'amount': payout.amount,
          'payment_channel': payout.paymentChannel,
          'payment_reference': payout.paymentReference,
          'note': payout.note,
          'paid_at': payout.paidAt.toUtc().toIso8601String(),
          'created_by_uid': payout.createdBy,
          'created_by_name': _safeName(
            payout.createdByName,
            fallback: 'Administration',
          ),
        },
      },
    );
  }

  Future<List<CommissionEntry>> fetchCommissions({String? agentId}) async {
    final String? id = _nullable(agentId);
    final List<Map<String, dynamic>> rows = id == null
        ? await _client
            .from('phase5_commissions')
            .select()
            .order('earned_at', ascending: false)
            .limit(staffHistoryLimit)
        : await _client
            .from('phase5_commissions')
            .select()
            .eq('agent_id', id)
            .order('earned_at', ascending: false)
            .limit(agentHistoryLimit);
    return rows.map(_commission).whereType<CommissionEntry>().toList(growable: false);
  }

  Future<List<CommissionPayout>> fetchCommissionPayouts({String? agentId}) async {
    final String? id = _nullable(agentId);
    final List<Map<String, dynamic>> rows = id == null
        ? await _client
            .from('phase5_commission_payouts')
            .select()
            .order('paid_at', ascending: false)
            .limit(staffHistoryLimit)
        : await _client
            .from('phase5_commission_payouts')
            .select()
            .eq('agent_id', id)
            .order('paid_at', ascending: false)
            .limit(agentHistoryLimit);
    return rows.map(_commissionPayout).whereType<CommissionPayout>().toList(growable: false);
  }

  Future<List<CommissionAccount>> fetchCommissionAccounts({String? agentId}) async {
    final String? id = _nullable(agentId);
    final List<Map<String, dynamic>> rows = id == null
        ? await _client.from('phase5_commission_accounts').select().order('agent_name')
        : await _client.from('phase5_commission_accounts').select().eq('agent_id', id).limit(1);
    return rows.map(_commissionAccount).whereType<CommissionAccount>().toList(growable: false);
  }

  Future<List<NetworkTransaction>> fetchNetworkMovements({String? agentId}) async {
    final String? id = _nullable(agentId);
    final List<Map<String, dynamic>> rows = id == null
        ? await _client
            .from('phase5_network_movements')
            .select()
            .order('occurred_at', ascending: false)
            .limit(staffHistoryLimit)
        : await _client
            .from('phase5_network_movements')
            .select()
            .eq('agent_id', id)
            .order('occurred_at', ascending: false)
            .limit(agentHistoryLimit);
    return rows.map(_networkMovement).whereType<NetworkTransaction>().toList(growable: false);
  }

  Future<List<SupplierAccount>> fetchSupplierAccounts() async {
    final List<Map<String, dynamic>> rows = await _client
        .from('phase5_supplier_accounts')
        .select()
        .order('supplier_name');
    return rows.map(_supplierAccount).whereType<SupplierAccount>().toList(growable: false);
  }

  Future<List<SupplierRecharge>> fetchSupplierRecharges({int limit = staffHistoryLimit}) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('phase5_agent_recharges')
        .select()
        .order('occurred_at', ascending: false)
        .limit(limit);
    return rows.map(_supplierRecharge).whereType<SupplierRecharge>().toList(growable: false);
  }

  Future<List<SupplierPayment>> fetchSupplierPayments({int limit = staffHistoryLimit}) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('phase5_supplier_payments')
        .select()
        .order('paid_at', ascending: false)
        .limit(limit);
    return rows.map(_supplierPayment).whereType<SupplierPayment>().toList(growable: false);
  }

  Stream<List<CommissionEntry>> watchCommissions({String? agentId}) =>
      _poll(() => fetchCommissions(agentId: agentId), 'commissions');
  Stream<List<CommissionPayout>> watchCommissionPayouts({String? agentId}) =>
      _poll(() => fetchCommissionPayouts(agentId: agentId), 'commission-payouts');
  Stream<List<CommissionAccount>> watchCommissionAccounts({String? agentId}) =>
      _poll(() => fetchCommissionAccounts(agentId: agentId), 'commission-accounts');
  Stream<List<NetworkTransaction>> watchNetworkMovements({String? agentId}) =>
      _poll(() => fetchNetworkMovements(agentId: agentId), 'network-movements');
  Stream<List<SupplierAccount>> watchSupplierAccounts() =>
      _poll(fetchSupplierAccounts, 'supplier-accounts');
  Stream<List<SupplierRecharge>> watchSupplierRecharges() =>
      _poll(fetchSupplierRecharges, 'supplier-recharges');
  Stream<List<SupplierPayment>> watchSupplierPayments() =>
      _poll(fetchSupplierPayments, 'supplier-payments');

  Stream<List<T>> _poll<T>(Future<List<T>> Function() fetch, String label) async* {
    List<T>? lastSuccessful;
    while (true) {
      try {
        final List<T> value = await fetch();
        lastSuccessful = value;
        yield value;
      } catch (error, stackTrace) {
        debugPrint('[Phase5][$label] $error');
        debugPrintStack(stackTrace: stackTrace);
        if (lastSuccessful == null) rethrow;
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  CommissionEntry? _commission(Map<String, dynamic> row) {
    final DateTime? earnedAt = _date(row['earned_at']);
    final MobileNetwork? network = _mobileNetwork(row['network']);
    if (earnedAt == null || network == null) return null;
    return CommissionEntry(
      id: _string(row['order_id']),
      orderId: _string(row['order_id']),
      orderReference: _string(row['order_reference']),
      agentId: _string(row['agent_id']),
      agentName: _string(row['agent_name']),
      network: network,
      orderAmount: _int(row['order_amount']),
      commissionAmount: _int(row['commission_amount']),
      policyId: _string(row['policy_id'], fallback: CommissionPolicy.current.id),
      policyType: CommissionPolicyType.fixedPerSuccessfulTransaction,
      rate: _int(row['rate']),
      earnedAt: earnedAt,
      processingStartedAt: _date(row['processing_started_at']),
    );
  }

  CommissionPayout? _commissionPayout(Map<String, dynamic> row) {
    final DateTime? paidAt = _date(row['paid_at']);
    if (paidAt == null) return null;
    return CommissionPayout(
      id: _string(row['id']),
      agentId: _string(row['agent_id']),
      agentName: _string(row['agent_name']),
      amount: _int(row['amount']),
      paymentChannel: _string(row['payment_channel'], fallback: 'wave'),
      paymentReference: _string(row['payment_reference']),
      paidAt: paidAt,
      createdBy: _string(row['created_by_uid']),
      createdByName: _string(row['created_by_name'], fallback: 'Administration'),
      note: _nullable(row['note']),
    );
  }

  CommissionAccount? _commissionAccount(Map<String, dynamic> row) {
    final DateTime? updatedAt = _date(row['updated_at']);
    if (updatedAt == null) return null;
    return CommissionAccount(
      agentId: _string(row['agent_id']),
      agentName: _string(row['agent_name']),
      earnedTotal: _int(row['earned_total']),
      paidTotal: _int(row['paid_total']),
      earnedTransactions: _int(row['earned_transactions']),
      updatedAt: updatedAt,
    );
  }

  NetworkTransaction? _networkMovement(Map<String, dynamic> row) {
    final DateTime? occurredAt = _date(row['occurred_at']);
    final AgentNetwork? network = _agentNetwork(row['network']);
    if (occurredAt == null || network == null) return null;
    return NetworkTransaction(
      id: _string(row['source_key'], fallback: _string(row['id'])),
      network: network,
      direction: _string(row['direction']) == 'incoming'
          ? NetworkTransactionDirection.incoming
          : NetworkTransactionDirection.outgoing,
      type: switch (_string(row['movement_type'])) {
        'supplierRecharge' => NetworkTransactionType.supplierRecharge,
        'manualAdjustment' => NetworkTransactionType.manualAdjustment,
        _ => NetworkTransactionType.orderSuccess,
      },
      amount: _int(row['amount']),
      capacityBefore: _int(row['capacity_before']),
      capacityAfter: _int(row['capacity_after']),
      agentId: _nullable(row['agent_id']),
      agentName: _nullable(row['agent_name']),
      orderId: _nullable(row['order_id']),
      orderReference: _nullable(row['order_reference']),
      supplierId: _nullable(row['supplier_id']),
      supplierName: _nullable(row['supplier_name']),
      supplierRechargeId: _nullable(row['supplier_recharge_id']),
      createdBy: _string(row['created_by_uid']),
      createdByRole: _string(row['created_by_role'], fallback: 'migration'),
      createdAt: occurredAt,
    );
  }

  SupplierAccount? _supplierAccount(Map<String, dynamic> row) {
    final DateTime? createdAt = _date(row['created_at']);
    final DateTime? updatedAt = _date(row['updated_at']);
    if (createdAt == null || updatedAt == null) return null;
    return SupplierAccount(
      supplierId: _string(row['supplier_id']),
      supplierName: _string(row['supplier_name']),
      totalOwed: _int(row['total_owed']),
      totalPaid: _int(row['total_paid']),
      totalRecharged: _int(row['total_recharged']),
      rechargeCount: _int(row['recharge_count']),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  SupplierRecharge? _supplierRecharge(Map<String, dynamic> row) {
    final DateTime? occurredAt = _date(row['occurred_at']);
    final AgentNetwork? network = _agentNetwork(row['network']);
    if (occurredAt == null || network == null) return null;
    return SupplierRecharge(
      id: _string(row['source_firestore_id']),
      supplierId: _string(row['supplier_id']),
      supplierName: _string(row['supplier_name']),
      agentId: _string(row['agent_id']),
      agentName: _string(row['agent_name']),
      network: network,
      principalAmount: _int(row['principal_amount']),
      bonusAmount: _int(row['bonus_amount']),
      receivedAmount: _int(row['received_amount']),
      amountOwed: _int(row['amount_owed']),
      capacityBefore: _int(row['capacity_before']),
      capacityAfter: _int(row['capacity_after']),
      note: _nullable(row['note']),
      createdAt: occurredAt,
      createdBy: _string(row['created_by_uid']),
      createdByName: _string(row['created_by_name'], fallback: 'Administration'),
    );
  }

  SupplierPayment? _supplierPayment(Map<String, dynamic> row) {
    final DateTime? paidAt = _date(row['paid_at']);
    if (paidAt == null) return null;
    return SupplierPayment(
      id: _string(row['source_firestore_id'], fallback: _string(row['id'])),
      supplierId: _string(row['supplier_id']),
      supplierName: _string(row['supplier_name']),
      amount: _int(row['amount']),
      channel: FinancePaymentChannelX.fromStorage(_string(row['payment_channel'])),
      reference: _string(row['payment_reference']),
      paidAt: paidAt,
      createdBy: _string(row['created_by_uid']),
      createdByName: _string(row['created_by_name'], fallback: 'Administration'),
      note: _nullable(row['note']),
    );
  }

  MobileNetwork? _mobileNetwork(Object? value) {
    final String text = _string(value).toLowerCase();
    for (final MobileNetwork item in MobileNetwork.values) {
      if (item.name == text) return item;
    }
    return null;
  }

  AgentNetwork? _agentNetwork(Object? value) {
    final String text = _string(value).toLowerCase();
    for (final AgentNetwork item in AgentNetwork.values) {
      if (item.firestoreValue == text) return item;
    }
    return null;
  }

  String _safeName(String? value, {String fallback = 'Agent'}) {
    final String text = (value ?? '').trim();
    return text.length >= 2 ? text : fallback;
  }

  String _string(Object? value, {String fallback = ''}) {
    final String text = value is String ? value.trim() : '';
    return text.isEmpty ? fallback : text;
  }

  String? _nullable(Object? value) {
    final String text = _string(value);
    return text.isEmpty ? null : text;
  }

  int _int(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  DateTime? _date(Object? value) {
    if (value is DateTime) return value.toLocal();
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }
}
