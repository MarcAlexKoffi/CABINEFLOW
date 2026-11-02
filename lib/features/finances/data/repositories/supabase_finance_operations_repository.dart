import 'package:cabine_flow/backoffice/data/repositories/supabase_backoffice_finance_repository.dart';
import 'package:cabine_flow/backoffice/domain/repositories/backoffice_finance_repository.dart';
import 'package:cabine_flow/core/supabase/supabase_realtime_refetch.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/finance_operations_repository.dart';
import 'package:cabine_flow/features/finances/domain/services/finance_calculators.dart';
import 'package:cabine_flow/features/finances/domain/services/finance_operation_key.dart';
import 'package:cabine_flow/features/orders/data/mappers/firestore_order_mapper.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin mobile and Back-office share one financial command API.
/// Firestore is read only when authorizing an unpaid legacy order.
class SupabaseFinanceOperationsRepository
    implements FinanceOperationsRepository {
  SupabaseFinanceOperationsRepository({
    SupabaseClient? client,
    BackofficeFinanceRepository? commands,
    Future<QueueOrder> Function(String)? loadOrder,
  }) : _providedClient = client,
       _providedCommands = commands,
       _loadOrder = loadOrder ?? _readLegacyOrder;

  final SupabaseClient? _providedClient;
  final BackofficeFinanceRepository? _providedCommands;
  BackofficeFinanceRepository? _resolvedCommands;
  SupabaseClient get _client => _providedClient ?? Supabase.instance.client;
  BackofficeFinanceRepository get _commands => _resolvedCommands ??=
      _providedCommands ?? SupabaseBackofficeFinanceRepository(client: _client);
  Future<void> _ensureReady() async {
    if (_providedClient != null || SupabaseBootstrap.isInitialized) return;
    if (!await SupabaseBootstrap.initialize()) {
      throw StateError(
        'Finance indisponible. Réessayez la connexion au registre canonique.',
      );
    }
  }

  final Future<QueueOrder> Function(String) _loadOrder;
  static const int pageSize = 250;
  final Expando<String> _draftKeys = Expando<String>('finance-intention');
  String _operationKey(Object draft) =>
      _draftKeys[draft] ??= createFinanceOperationKey();

  Future<WaveCashSnapshot> fetchWaveSnapshot() async {
    await _ensureReady();
    final snapshot = await _commands.fetchSnapshot();
    if (snapshot.waveTotals == null) {
      throw StateError(
        'Les totaux Wave serveur doivent être installés avant la recette mobile.',
      );
    }
    return WaveCashSnapshot(
      openingBalance: snapshot.openingWaveBalance,
      clientPayments: snapshot.waveClientPaymentsSinceOpening,
      creditSettlements: snapshot.waveCreditSettlementsSinceOpening,
      supplierPayments: snapshot.waveSupplierPaymentsSinceOpening,
      refunds: snapshot.waveRefundsSinceOpening,
      expenses: snapshot.waveExpensesSinceOpening,
      commissionPayouts: snapshot.waveCommissionPayoutsSinceOpening,
      cabinistePayouts: snapshot.waveCabinistePayoutsSinceOpening,
      theoreticalBalance: snapshot.waveTheoreticalBalance,
      effectiveAt:
          snapshot.waveOpeningEffectiveAt ??
          DateTime.fromMillisecondsSinceEpoch(0),
      hasOpeningBalance: snapshot.hasWaveOpening,
    );
  }

  static Future<QueueOrder> _readLegacyOrder(String id) async {
    final document = await FirebaseFirestore.instance
        .collection('orders')
        .doc(id)
        .get(const GetOptions(source: Source.server));
    final data = document.data();
    if (data == null) throw StateError('Commande introuvable.');
    return FirestoreOrderMapper.fromMap(id: id, data: data);
  }

  Future<List<Map<String, dynamic>>> fetchRows(String kind) async {
    await _ensureReady();
    final result = <Map<String, dynamic>>[];
    String? after;
    final key = switch (kind) {
      'closings' => 'date_key',
      'supplier_accounts' => 'supplier_id',
      'supplier_recharges' => 'source_firestore_id',
      _ => 'id',
    };
    while (true) {
      final Object? response = await _client.rpc(
        'izytel_finance_read_page',
        params: <String, dynamic>{
          'p_kind': kind,
          'p_after': after,
          'p_limit': pageSize,
        },
      );
      if (response is! List) throw StateError('Page financière invalide.');
      final rows = response
          .map((dynamic row) => Map<String, dynamic>.from(row as Map))
          .toList();
      result.addAll(rows);
      if (rows.length < pageSize) return result;
      final next = rows.last[key]?.toString();
      if (next == null || next.isEmpty || next == after) {
        throw StateError('Curseur financier invalide.');
      }
      after = next;
    }
  }

  Stream<List<T>> _watch<T>(
    String kind,
    T Function(Map<String, dynamic>) decode,
  ) async* {
    await _ensureReady();
    yield* SupabaseRealtimeRefetch.watch<List<T>>(
      client: _client,
      label: 'Finance.canonical.$kind',
      signals: const <SupabaseRealtimeSignal>[
        SupabaseRealtimeSignal(
          table: 'finance_change_feed',
          primaryKey: <String>['id'],
        ),
      ],
      fetch: () async =>
          (await fetchRows(kind)).map(decode).toList(growable: false),
    );
  }

  @override
  Stream<List<FinanceSupplier>> watchSuppliers() async* {
    await _ensureReady();
    yield* _commands.watchSnapshot().map(
      (s) => s.suppliers.map(FinanceSqlMapper.supplier).toList(),
    );
  }

  @override
  Stream<List<SupplierAccount>> watchSupplierAccounts() =>
      _watch('supplier_accounts', FinanceSqlMapper.supplierAccount);
  @override
  Stream<List<SupplierRecharge>> watchSupplierRecharges() =>
      _watch('supplier_recharges', FinanceSqlMapper.recharge);
  @override
  Stream<List<SupplierPayment>> watchSupplierPayments() =>
      _watch('supplier_payments', FinanceSqlMapper.supplierPayment);
  @override
  Stream<List<CustomerCredit>> watchCustomerCredits() =>
      _watch('credits', FinanceSqlMapper.credit);
  @override
  Stream<List<CustomerCreditSettlement>> watchCustomerCreditSettlements() =>
      _watch('settlements', FinanceSqlMapper.settlement);
  @override
  Stream<List<FinanceExpense>> watchExpenses() =>
      _watch('expenses', FinanceSqlMapper.expense);
  @override
  Stream<WaveOpeningBalance?> watchWaveOpeningBalance() => _watch(
    'opening',
    FinanceSqlMapper.opening,
  ).map((rows) => rows.isEmpty ? null : rows.single);
  @override
  Stream<List<WaveBalanceAdjustment>> watchWaveBalanceAdjustments() =>
      _watch('adjustments', FinanceSqlMapper.adjustment);
  @override
  Stream<List<DailyFinancialClosing>> watchDailyClosings() =>
      _watch('closings', FinanceSqlMapper.closing);

  @override
  Future<String> createSupplier({
    required String name,
    required String phoneNumber,
    required String staffId,
    required String staffName,
    String? note,
  }) =>
      _commands.saveSupplier(name: name, phoneNumber: phoneNumber, note: note);
  @override
  Future<void> updateSupplier({
    required String supplierId,
    required String name,
    required String phoneNumber,
    required String staffId,
    required String staffName,
    String? note,
  }) async {
    await _commands.saveSupplier(
      supplierId: supplierId,
      name: name,
      phoneNumber: phoneNumber,
      note: note,
    );
  }

  @override
  Future<void> setSupplierActive({
    required String supplierId,
    required bool isActive,
    required String staffId,
    required String staffName,
  }) => _commands.setSupplierActive(supplierId: supplierId, isActive: isActive);
  @override
  Future<void> deleteSupplier({required String supplierId}) =>
      _commands.deleteSupplier(supplierId);
  @override
  Future<String> recordSupplierRecharge({
    required SupplierRechargeDraft draft,
    required String staffId,
    required String staffName,
  }) => _commands.recordSupplierRecharge(
    operationKey: _operationKey(draft),
    supplierId: draft.supplierId,
    agentId: draft.agentId,
    agentName: draft.agentName,
    network: draft.network.firestoreValue,
    principal: draft.principalAmount,
    bonus: draft.bonusAmount,
    amountOwed: draft.amountOwed,
    note: draft.note,
    staffName: staffName,
  );
  @override
  Future<String> recordSupplierPayment({
    required SupplierPaymentDraft draft,
    required String staffId,
    required String staffName,
  }) => _commands.recordSupplierPayment(
    operationKey: _operationKey(draft),
    supplierId: draft.supplierId,
    amount: draft.amount,
    channel: draft.channel.storageValue,
    reference: draft.reference,
    note: draft.note,
    staffName: staffName,
  );
  @override
  Future<String> createCustomerCredit({
    required CustomerCreditDraft draft,
    required String staffId,
    required String staffName,
  }) async {
    final order = await _loadOrder(draft.orderId);
    if (order.amount != draft.amount ||
        order.reference != draft.orderReference) {
      throw StateError(
        'La commande a changé. Rechargez-la avant autorisation.',
      );
    }
    return _commands.authorizeCreditOrder(order: order, note: draft.note);
  }

  @override
  Future<String> settleCustomerCredit({
    required String creditId,
    required int amount,
    required FinancePaymentChannel channel,
    required String reference,
    required String staffId,
    required String staffName,
    String? note,
  }) => _commands.settleCredit(
    creditId: creditId,
    amount: amount,
    channel: channel.storageValue,
    reference: reference,
    note: note,
  );
  @override
  Future<String> recordExpense({
    required FinanceExpenseDraft draft,
    required String staffId,
    required String staffName,
  }) => _commands.recordExpense(
    operationKey: _operationKey(draft),
    category: draft.category.storageValue,
    amount: draft.amount,
    description: draft.description,
    channel: draft.channel.storageValue,
    reference: draft.reference,
  );
  @override
  Future<void> setWaveOpeningBalance({
    required int amount,
    required String staffId,
    required String staffName,
    String? note,
  }) => _commands.setWaveOpening(amount: amount, note: note);
  @override
  Future<void> createDailyClosing({
    required DailyFinancialClosingDraft draft,
    required String staffId,
    required String staffName,
  }) async {
    // Server recomputes every business total; only the actual count is input.
    final rawKey = draft.dateKey;
    final dateKey = RegExp(r'^\d{8}$').hasMatch(rawKey)
        ? '${rawKey.substring(0, 4)}-${rawKey.substring(4, 6)}-${rawKey.substring(6, 8)}'
        : rawKey;
    await _commands.createClosing(<String, dynamic>{
      'date_key': dateKey,
      'wave_actual_balance': draft.waveActualBalance,
      'wave_difference_note': draft.waveDifferenceNote,
    });
  }
}

class FinanceSqlMapper {
  static String s(Map<String, dynamic> r, String k) => r[k]?.toString() ?? '';
  static int n(Map<String, dynamic> r, String k) {
    final value = r[k];
    return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }

  static DateTime d(Map<String, dynamic> r, String k) {
    final value = DateTime.tryParse(s(r, k));
    if (value == null) {
      throw FormatException('Date financière absente ou invalide : $k');
    }
    return value.toLocal();
  }

  static FinancePaymentChannel channel(Map<String, dynamic> r) =>
      FinancePaymentChannelX.fromStorage(s(r, 'payment_channel'));
  static FinanceSupplier supplier(Map<String, dynamic> r) => FinanceSupplier(
    id: s(r, 'id'),
    name: s(r, 'name'),
    phoneNumber: s(r, 'phone_number'),
    isActive: r['is_active'] == true,
    createdAt: d(r, 'created_at'),
    updatedAt: d(r, 'updated_at'),
    createdBy: s(r, 'created_by_uid'),
    createdByName: s(r, 'created_by_name'),
    note: r['note'] as String?,
  );
  static SupplierAccount supplierAccount(Map<String, dynamic> r) =>
      SupplierAccount(
        supplierId: s(r, 'supplier_id'),
        supplierName: s(r, 'supplier_name'),
        totalOwed: n(r, 'total_owed'),
        totalPaid: n(r, 'total_paid'),
        totalRecharged: n(r, 'total_recharged'),
        rechargeCount: n(r, 'recharge_count'),
        createdAt: d(r, 'created_at'),
        updatedAt: d(r, 'updated_at'),
      );
  static SupplierRecharge recharge(Map<String, dynamic> r) => SupplierRecharge(
    id: s(r, 'source_firestore_id'),
    supplierId: s(r, 'supplier_id'),
    supplierName: s(r, 'supplier_name'),
    agentId: s(r, 'agent_id'),
    agentName: s(r, 'agent_name'),
    network: AgentNetwork.values.firstWhere(
      (n) => n.firestoreValue == s(r, 'network'),
    ),
    principalAmount: n(r, 'principal_amount'),
    bonusAmount: n(r, 'bonus_amount'),
    receivedAmount: n(r, 'received_amount'),
    amountOwed: n(r, 'amount_owed'),
    capacityBefore: n(r, 'capacity_before'),
    capacityAfter: n(r, 'capacity_after'),
    createdAt: d(r, 'occurred_at'),
    createdBy: s(r, 'created_by_uid'),
    createdByName: s(r, 'created_by_name'),
    note: r['note'] as String?,
  );
  static SupplierPayment supplierPayment(Map<String, dynamic> r) =>
      SupplierPayment(
        id: s(r, 'id'),
        supplierId: s(r, 'supplier_id'),
        supplierName: s(r, 'supplier_name'),
        amount: n(r, 'amount'),
        channel: channel(r),
        reference: s(r, 'payment_reference'),
        paidAt: d(r, 'paid_at'),
        createdBy: s(r, 'created_by_uid'),
        createdByName: s(r, 'created_by_name'),
        note: r['note'] as String?,
      );
  static CustomerCredit credit(Map<String, dynamic> r) => CustomerCredit(
    id: s(r, 'id'),
    orderId: s(r, 'order_id'),
    orderReference: s(r, 'order_reference'),
    clientName: s(r, 'client_name'),
    clientWhatsappPhone: s(r, 'client_whatsapp_phone'),
    amount: n(r, 'amount'),
    paidAmount: n(r, 'paid_amount'),
    status: CustomerCreditStatusX.fromStorage(s(r, 'status')),
    createdAt: d(r, 'created_at'),
    updatedAt: d(r, 'updated_at'),
    createdBy: s(r, 'created_by_uid'),
    createdByName: s(r, 'created_by_name'),
    note: r['note'] as String?,
    settledAt: DateTime.tryParse(s(r, 'settled_at'))?.toLocal(),
  );
  static CustomerCreditSettlement settlement(Map<String, dynamic> r) =>
      CustomerCreditSettlement(
        id: s(r, 'id'),
        creditId: s(r, 'credit_id'),
        orderId: s(r, 'order_id'),
        orderReference: s(r, 'order_reference'),
        clientName: s(r, 'client_name'),
        amount: n(r, 'amount'),
        channel: channel(r),
        reference: s(r, 'payment_reference'),
        paidAt: d(r, 'paid_at'),
        createdBy: s(r, 'created_by_uid'),
        createdByName: s(r, 'created_by_name'),
        note: r['note'] as String?,
      );
  static FinanceExpense expense(Map<String, dynamic> r) => FinanceExpense(
    id: s(r, 'id'),
    category: FinanceExpenseCategoryX.fromStorage(s(r, 'category')),
    amount: n(r, 'amount'),
    description: s(r, 'description'),
    channel: channel(r),
    spentAt: d(r, 'spent_at'),
    reference: r['payment_reference'] as String?,
    createdBy: s(r, 'created_by_uid'),
    createdByName: s(r, 'created_by_name'),
  );
  static WaveOpeningBalance opening(Map<String, dynamic> r) =>
      WaveOpeningBalance(
        amount: n(r, 'opening_balance'),
        effectiveAt: d(r, 'effective_at'),
        updatedAt: d(r, 'updated_at'),
        updatedBy: s(r, 'updated_by_uid'),
        updatedByName: s(r, 'updated_by_name'),
        note: r['note'] as String?,
      );
  static WaveBalanceAdjustment adjustment(Map<String, dynamic> r) =>
      WaveBalanceAdjustment(
        id: s(r, 'id'),
        previousOpeningBalance: n(r, 'previous_opening_balance'),
        openingBalance: n(r, 'opening_balance'),
        effectiveAt: d(r, 'effective_at'),
        createdBy: s(r, 'created_by_uid'),
        createdByName: s(r, 'created_by_name'),
        note: r['note'] as String?,
      );
  static DailyFinancialClosing closing(Map<String, dynamic> r) =>
      DailyFinancialClosing(
        id: s(r, 'date_key'),
        dateKey: s(r, 'date_key').replaceAll('-', ''),
        clientReceipts: n(r, 'client_receipts'),
        successfulOrdersCount: n(r, 'successful_orders_count'),
        successfulOrdersAmount: n(r, 'successful_orders_amount'),
        supplierRechargePrincipal: n(r, 'supplier_recharge_principal'),
        supplierRechargeBonus: n(r, 'supplier_recharge_bonus'),
        supplierRechargeReceived: n(r, 'supplier_recharge_received'),
        supplierPayments: n(r, 'supplier_payments'),
        creditsCreated: n(r, 'credits_created'),
        creditSettlements: n(r, 'credit_settlements'),
        customerReceivables: n(r, 'customer_receivables'),
        expenses: n(r, 'expenses'),
        refunds: n(r, 'refunds'),
        commissionsEarned: n(r, 'commissions_earned'),
        commissionsPaid: n(r, 'commissions_paid'),
        orangeAvailable: n(r, 'orange_available'),
        orangeCommitted: n(r, 'orange_committed'),
        mtnAvailable: n(r, 'mtn_available'),
        mtnCommitted: n(r, 'mtn_committed'),
        moovAvailable: n(r, 'moov_available'),
        moovCommitted: n(r, 'moov_committed'),
        supplierDebt: n(r, 'supplier_debt'),
        commissionDebt: n(r, 'commission_debt'),
        waveTheoreticalBalance: n(r, 'wave_theoretical_balance'),
        waveActualBalance: n(r, 'wave_actual_balance'),
        waveDifference: n(r, 'wave_difference'),
        estimatedProfit: n(r, 'estimated_profit'),
        waveDifferenceNote: r['wave_difference_note'] as String?,
        closedAt: d(r, 'closed_at'),
        closedBy: s(r, 'closed_by_uid'),
        closedByName: s(r, 'closed_by_name'),
      );
}
