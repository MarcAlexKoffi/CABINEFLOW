import 'dart:async';

import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/finance_operations_repository.dart';

class FakeFinanceOperationsRepository implements FinanceOperationsRepository {
  FakeFinanceOperationsRepository({
    Iterable<FinanceSupplier> suppliers = const <FinanceSupplier>[],
    Iterable<SupplierAccount> supplierAccounts = const <SupplierAccount>[],
    Iterable<SupplierRecharge> recharges = const <SupplierRecharge>[],
    Iterable<SupplierPayment> supplierPayments = const <SupplierPayment>[],
    Iterable<CustomerCredit> credits = const <CustomerCredit>[],
    Iterable<CustomerCreditSettlement> settlements = const <CustomerCreditSettlement>[],
    Iterable<FinanceExpense> expenses = const <FinanceExpense>[],
    WaveOpeningBalance? waveOpening,
    Iterable<WaveBalanceAdjustment> waveAdjustments = const <WaveBalanceAdjustment>[],
    Iterable<DailyFinancialClosing> closings = const <DailyFinancialClosing>[],
  })  : _suppliers = List<FinanceSupplier>.from(suppliers),
        _supplierAccounts = List<SupplierAccount>.from(supplierAccounts),
        _recharges = List<SupplierRecharge>.from(recharges),
        _supplierPayments = List<SupplierPayment>.from(supplierPayments),
        _credits = List<CustomerCredit>.from(credits),
        _settlements = List<CustomerCreditSettlement>.from(settlements),
        _expenses = List<FinanceExpense>.from(expenses),
        _waveOpening = waveOpening,
        _waveAdjustments = List<WaveBalanceAdjustment>.from(waveAdjustments),
        _closings = List<DailyFinancialClosing>.from(closings);

  final List<FinanceSupplier> _suppliers;
  final List<SupplierAccount> _supplierAccounts;
  final List<SupplierRecharge> _recharges;
  final List<SupplierPayment> _supplierPayments;
  final List<CustomerCredit> _credits;
  final List<CustomerCreditSettlement> _settlements;
  final List<FinanceExpense> _expenses;
  WaveOpeningBalance? _waveOpening;
  final List<WaveBalanceAdjustment> _waveAdjustments;
  final List<DailyFinancialClosing> _closings;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _sequence = 0;

  @override
  Stream<List<FinanceSupplier>> watchSuppliers() async* {
    yield _sortedSuppliers();
    yield* _changes.stream.map((_) => _sortedSuppliers());
  }

  @override
  Stream<List<SupplierAccount>> watchSupplierAccounts() async* {
    yield List<SupplierAccount>.unmodifiable(_supplierAccounts);
    yield* _changes.stream.map((_) => List<SupplierAccount>.unmodifiable(_supplierAccounts));
  }

  @override
  Stream<List<SupplierRecharge>> watchSupplierRecharges() async* {
    yield _sortedByDate(_recharges, (SupplierRecharge value) => value.createdAt);
    yield* _changes.stream.map((_) => _sortedByDate(_recharges, (SupplierRecharge value) => value.createdAt));
  }

  @override
  Stream<List<SupplierPayment>> watchSupplierPayments() async* {
    yield _sortedByDate(_supplierPayments, (SupplierPayment value) => value.paidAt);
    yield* _changes.stream.map((_) => _sortedByDate(_supplierPayments, (SupplierPayment value) => value.paidAt));
  }

  @override
  Stream<List<CustomerCredit>> watchCustomerCredits() async* {
    yield _sortedByDate(_credits, (CustomerCredit value) => value.updatedAt);
    yield* _changes.stream.map((_) => _sortedByDate(_credits, (CustomerCredit value) => value.updatedAt));
  }

  @override
  Stream<List<CustomerCreditSettlement>> watchCustomerCreditSettlements() async* {
    yield _sortedByDate(_settlements, (CustomerCreditSettlement value) => value.paidAt);
    yield* _changes.stream.map((_) => _sortedByDate(_settlements, (CustomerCreditSettlement value) => value.paidAt));
  }

  @override
  Stream<List<FinanceExpense>> watchExpenses() async* {
    yield _sortedByDate(_expenses, (FinanceExpense value) => value.spentAt);
    yield* _changes.stream.map((_) => _sortedByDate(_expenses, (FinanceExpense value) => value.spentAt));
  }

  @override
  Stream<WaveOpeningBalance?> watchWaveOpeningBalance() async* {
    yield _waveOpening;
    yield* _changes.stream.map((_) => _waveOpening);
  }

  @override
  Stream<List<WaveBalanceAdjustment>> watchWaveBalanceAdjustments() async* {
    yield _sortedByDate(_waveAdjustments, (WaveBalanceAdjustment value) => value.effectiveAt);
    yield* _changes.stream.map((_) => _sortedByDate(_waveAdjustments, (WaveBalanceAdjustment value) => value.effectiveAt));
  }

  @override
  Stream<List<DailyFinancialClosing>> watchDailyClosings() async* {
    yield _sortedByDate(_closings, (DailyFinancialClosing value) => value.closedAt);
    yield* _changes.stream.map((_) => _sortedByDate(_closings, (DailyFinancialClosing value) => value.closedAt));
  }

  @override
  Future<String> createSupplier({required String name, required String phoneNumber, required String staffId, required String staffName, String? note}) async {
    final DateTime now = DateTime.now();
    final String id = _id('supplier');
    _suppliers.add(FinanceSupplier(
      id: id,
      name: name.trim(),
      phoneNumber: phoneNumber.trim(),
      isActive: true,
      note: _nullable(note),
      createdAt: now,
      createdBy: staffId,
      createdByName: staffName,
      updatedAt: now,
    ));
    _notify();
    return id;
  }

  @override
  Future<void> setSupplierActive({required String supplierId, required bool isActive, required String staffId, required String staffName}) async {
    final int index = _suppliers.indexWhere((FinanceSupplier item) => item.id == supplierId);
    if (index < 0) throw StateError('Fournisseur introuvable.');
    final FinanceSupplier current = _suppliers[index];
    _suppliers[index] = FinanceSupplier(
      id: current.id,
      name: current.name,
      phoneNumber: current.phoneNumber,
      isActive: isActive,
      note: current.note,
      createdAt: current.createdAt,
      createdBy: current.createdBy,
      createdByName: current.createdByName,
      updatedAt: DateTime.now(),
    );
    _notify();
  }

  @override
  Future<String> recordSupplierRecharge({required SupplierRechargeDraft draft, required String staffId, required String staffName}) async {
    if (draft.principalAmount <= 0 || draft.bonusAmount < 0 || draft.receivedAmount <= 0) {
      throw ArgumentError('Les montants de recharge sont invalides.');
    }
    if (draft.amountOwed != draft.principalAmount) {
      throw ArgumentError('Une recharge crée d’abord la dette complète du principal.');
    }
    final DateTime now = DateTime.now();
    final String id = _id('recharge');
    final SupplierAccount? current = _account(draft.supplierId);
    _recharges.add(SupplierRecharge(
      id: id,
      supplierId: draft.supplierId,
      supplierName: draft.supplierName,
      agentId: draft.agentId,
      agentName: draft.agentName,
      network: draft.network,
      principalAmount: draft.principalAmount,
      bonusAmount: draft.bonusAmount,
      receivedAmount: draft.receivedAmount,
      amountOwed: draft.amountOwed,
      capacityBefore: 0,
      capacityAfter: draft.receivedAmount,
      note: draft.note,
      createdAt: now,
      createdBy: staffId,
      createdByName: staffName,
    ));
    _upsertAccount(SupplierAccount(
      supplierId: draft.supplierId,
      supplierName: draft.supplierName,
      totalOwed: (current?.totalOwed ?? 0) + draft.amountOwed,
      totalPaid: current?.totalPaid ?? 0,
      totalRecharged: (current?.totalRecharged ?? 0) + draft.receivedAmount,
      rechargeCount: (current?.rechargeCount ?? 0) + 1,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
    ));
    _notify();
    return id;
  }

  @override
  Future<String> recordSupplierPayment({required SupplierPaymentDraft draft, required String staffId, required String staffName}) async {
    if (draft.amount <= 0) throw ArgumentError('Le montant du règlement doit être positif.');
    if (draft.reference.trim().length < 3) throw ArgumentError('La référence du règlement est requise.');
    final SupplierAccount? current = _account(draft.supplierId);
    if (current == null || draft.amount > current.balance) throw StateError('Le règlement dépasse le solde fournisseur.');
    final DateTime now = DateTime.now();
    final String id = _id('supplierPayment');
    _supplierPayments.add(SupplierPayment(
      id: id,
      supplierId: draft.supplierId,
      supplierName: draft.supplierName,
      amount: draft.amount,
      channel: draft.channel,
      reference: draft.reference,
      note: draft.note,
      paidAt: now,
      createdBy: staffId,
      createdByName: staffName,
    ));
    _upsertAccount(SupplierAccount(
      supplierId: current.supplierId,
      supplierName: current.supplierName,
      totalOwed: current.totalOwed,
      totalPaid: current.totalPaid + draft.amount,
      totalRecharged: current.totalRecharged,
      rechargeCount: current.rechargeCount,
      createdAt: current.createdAt,
      updatedAt: now,
    ));
    _notify();
    return id;
  }

  @override
  Future<String> createCustomerCredit({required CustomerCreditDraft draft, required String staffId, required String staffName}) async {
    if (draft.amount <= 0) throw ArgumentError('Le montant du crédit doit être positif.');
    if (_credits.any((CustomerCredit item) => item.orderId == draft.orderId)) throw StateError('Un crédit existe déjà pour cette commande.');
    final DateTime now = DateTime.now();
    final CustomerCredit credit = CustomerCredit(
      id: draft.orderId,
      orderId: draft.orderId,
      orderReference: draft.orderReference,
      clientName: draft.clientName,
      clientWhatsappPhone: draft.clientWhatsappPhone,
      amount: draft.amount,
      paidAmount: 0,
      status: CustomerCreditStatus.open,
      note: draft.note,
      createdAt: now,
      createdBy: staffId,
      createdByName: staffName,
      updatedAt: now,
    );
    _credits.add(credit);
    _notify();
    return credit.id;
  }

  @override
  Future<String> settleCustomerCredit({required String creditId, required int amount, required FinancePaymentChannel channel, required String reference, required String staffId, required String staffName, String? note}) async {
    if (reference.trim().length < 3) throw ArgumentError('La référence du règlement est requise.');
    final int index = _credits.indexWhere((CustomerCredit item) => item.id == creditId);
    if (index < 0) throw StateError('Crédit client introuvable.');
    final CustomerCredit current = _credits[index];
    if (amount <= 0 || amount > current.outstanding) throw StateError('Montant de règlement invalide.');
    final DateTime now = DateTime.now();
    final int nextPaid = current.paidAmount + amount;
    final bool settled = nextPaid == current.amount;
    _credits[index] = CustomerCredit(
      id: current.id,
      orderId: current.orderId,
      orderReference: current.orderReference,
      clientName: current.clientName,
      clientWhatsappPhone: current.clientWhatsappPhone,
      amount: current.amount,
      paidAmount: nextPaid,
      status: settled ? CustomerCreditStatus.settled : CustomerCreditStatus.partial,
      note: current.note,
      createdAt: current.createdAt,
      createdBy: current.createdBy,
      createdByName: current.createdByName,
      updatedAt: now,
      settledAt: settled ? now : null,
    );
    final String id = _id('creditSettlement');
    _settlements.add(CustomerCreditSettlement(
      id: id,
      creditId: creditId,
      orderId: current.orderId,
      orderReference: current.orderReference,
      clientName: current.clientName,
      amount: amount,
      channel: channel,
      reference: reference,
      note: note,
      paidAt: now,
      createdBy: staffId,
      createdByName: staffName,
    ));
    _notify();
    return id;
  }

  @override
  Future<String> recordExpense({required FinanceExpenseDraft draft, required String staffId, required String staffName}) async {
    if (draft.amount <= 0) throw ArgumentError('Le montant de la dépense doit être positif.');
    if (draft.description.trim().length < 3) throw ArgumentError('La description de la dépense est requise.');
    if (draft.channel == FinancePaymentChannel.wave && (draft.reference?.trim().length ?? 0) < 3) {
      throw ArgumentError('La référence Wave est requise pour une dépense payée via Wave.');
    }
    final DateTime now = DateTime.now();
    final String id = _id('expense');
    _expenses.add(FinanceExpense(
      id: id,
      category: draft.category,
      amount: draft.amount,
      description: draft.description,
      channel: draft.channel,
      reference: draft.reference,
      spentAt: now,
      createdBy: staffId,
      createdByName: staffName,
    ));
    _notify();
    return id;
  }

  @override
  Future<void> setWaveOpeningBalance({required int amount, required String staffId, required String staffName, String? note}) async {
    if (amount < 0) throw ArgumentError('Le solde Wave ne peut pas être négatif.');
    final DateTime now = DateTime.now();
    final int previous = _waveOpening?.amount ?? 0;
    final String adjustmentId = _id('waveAdjustment');
    _waveAdjustments.add(WaveBalanceAdjustment(
      id: adjustmentId,
      previousOpeningBalance: previous,
      openingBalance: amount,
      effectiveAt: now,
      note: _nullable(note),
      createdBy: staffId,
      createdByName: staffName,
    ));
    _waveOpening = WaveOpeningBalance(
      amount: amount,
      effectiveAt: now,
      note: _nullable(note),
      updatedAt: now,
      updatedBy: staffId,
      updatedByName: staffName,
    );
    _notify();
  }

  @override
  Future<void> createDailyClosing({required DailyFinancialClosingDraft draft, required String staffId, required String staffName}) async {
    if (_closings.any((DailyFinancialClosing item) => item.dateKey == draft.dateKey)) throw StateError('Cette journée a déjà été clôturée.');
    if (draft.waveActualBalance < 0) throw ArgumentError('Le solde Wave réel est invalide.');
    if (draft.waveDifference != 0 && (draft.waveDifferenceNote?.trim().length ?? 0) < 3) {
      throw ArgumentError('Un écart Wave doit être justifié.');
    }
    final DateTime now = DateTime.now();
    _closings.add(DailyFinancialClosing(
      id: draft.dateKey,
      dateKey: draft.dateKey,
      clientReceipts: draft.clientReceipts,
      successfulOrdersCount: draft.successfulOrdersCount,
      successfulOrdersAmount: draft.successfulOrdersAmount,
      supplierRechargePrincipal: draft.supplierRechargePrincipal,
      supplierRechargeBonus: draft.supplierRechargeBonus,
      supplierRechargeReceived: draft.supplierRechargeReceived,
      supplierPayments: draft.supplierPayments,
      creditsCreated: draft.creditsCreated,
      creditSettlements: draft.creditSettlements,
      customerReceivables: draft.customerReceivables,
      expenses: draft.expenses,
      refunds: draft.refunds,
      commissionsEarned: draft.commissionsEarned,
      commissionsPaid: draft.commissionsPaid,
      orangeAvailable: draft.orangeAvailable,
      orangeCommitted: draft.orangeCommitted,
      mtnAvailable: draft.mtnAvailable,
      mtnCommitted: draft.mtnCommitted,
      moovAvailable: draft.moovAvailable,
      moovCommitted: draft.moovCommitted,
      supplierDebt: draft.supplierDebt,
      commissionDebt: draft.commissionDebt,
      waveTheoreticalBalance: draft.waveTheoreticalBalance,
      waveActualBalance: draft.waveActualBalance,
      waveDifference: draft.waveDifference,
      estimatedProfit: draft.estimatedProfit,
      waveDifferenceNote: _nullable(draft.waveDifferenceNote),
      closedAt: now,
      closedBy: staffId,
      closedByName: staffName,
    ));
    _notify();
  }

  SupplierAccount? _account(String supplierId) {
    for (final SupplierAccount item in _supplierAccounts) {
      if (item.supplierId == supplierId) return item;
    }
    return null;
  }

  void _upsertAccount(SupplierAccount account) {
    final int index = _supplierAccounts.indexWhere((SupplierAccount item) => item.supplierId == account.supplierId);
    if (index < 0) {
      _supplierAccounts.add(account);
    } else {
      _supplierAccounts[index] = account;
    }
  }

  List<FinanceSupplier> _sortedSuppliers() {
    final List<FinanceSupplier> result = List<FinanceSupplier>.from(_suppliers)
      ..sort((FinanceSupplier a, FinanceSupplier b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List<FinanceSupplier>.unmodifiable(result);
  }

  List<T> _sortedByDate<T>(List<T> source, DateTime Function(T value) date) {
    final List<MapEntry<int, T>> indexed = source.asMap().entries.toList()
      ..sort((MapEntry<int, T> a, MapEntry<int, T> b) {
        final int byDate = date(b.value).compareTo(date(a.value));
        if (byDate != 0) {
          return byDate;
        }

        // Deux opérations du fake peuvent être créées dans la même microseconde.
        // Dans ce cas, l'élément inséré le plus récemment doit rester le premier,
        // comme le ferait une liste Firestore triée par événement le plus récent.
        return b.key.compareTo(a.key);
      });

    return List<T>.unmodifiable(
      indexed.map((MapEntry<int, T> entry) => entry.value),
    );
  }

  String _id(String prefix) => '${prefix}_${++_sequence}';
  String? _nullable(String? value) {
    final String cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }
  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }
  Future<void> dispose() => _changes.close();
}
