import 'dart:async';

import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';

class FakeCommissionRepository implements CommissionRepository {
  FakeCommissionRepository({
    List<CommissionEntry>? commissions,
    List<CommissionPayout>? payouts,
    List<CommissionAccount>? accounts,
    List<AgentAssignmentMetric>? assignments,
    List<AgentProcessingMetric>? processingMetrics,
    List<AgentOrderMetric>? orderMetrics,
  }) : _commissions = List<CommissionEntry>.from(
         commissions ?? const <CommissionEntry>[],
       ),
       _payouts = List<CommissionPayout>.from(
         payouts ?? const <CommissionPayout>[],
       ),
       _accounts = <String, CommissionAccount>{
         for (final CommissionAccount value
             in accounts ?? const <CommissionAccount>[])
           value.agentId: value,
       },
       _assignments = List<AgentAssignmentMetric>.from(
         assignments ?? const <AgentAssignmentMetric>[],
       ),
       _processingMetrics = List<AgentProcessingMetric>.from(
         processingMetrics ?? const <AgentProcessingMetric>[],
       ),
       _orderMetrics = List<AgentOrderMetric>.from(
         orderMetrics ?? const <AgentOrderMetric>[],
       );

  final List<CommissionEntry> _commissions;
  final List<CommissionPayout> _payouts;
  final Map<String, CommissionAccount> _accounts;
  final List<AgentAssignmentMetric> _assignments;
  final List<AgentProcessingMetric> _processingMetrics;
  final List<AgentOrderMetric> _orderMetrics;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  List<T> _filtered<T>(List<T> source, String? agentId, String Function(T) id) {
    final String cleaned = agentId?.trim() ?? '';
    if (cleaned.isEmpty) return List<T>.from(source);
    return source
        .where((T value) => id(value) == cleaned)
        .toList(growable: false);
  }

  @override
  Stream<List<CommissionEntry>> watchCommissions({String? agentId}) async* {
    List<CommissionEntry> current() {
      final List<CommissionEntry> values = _filtered(
        _commissions,
        agentId,
        (CommissionEntry value) => value.agentId,
      );
      values.sort((a, b) => b.earnedAt.compareTo(a.earnedAt));
      return values;
    }

    yield current();
    yield* _changes.stream.map((_) => current());
  }

  @override
  Stream<List<CommissionPayout>> watchPayouts({String? agentId}) async* {
    List<CommissionPayout> current() {
      final List<CommissionPayout> values = _filtered(
        _payouts,
        agentId,
        (CommissionPayout value) => value.agentId,
      );
      values.sort((a, b) => b.paidAt.compareTo(a.paidAt));
      return values;
    }

    yield current();
    yield* _changes.stream.map((_) => current());
  }

  @override
  Stream<List<CommissionAccount>> watchAccounts({String? agentId}) async* {
    List<CommissionAccount> current() {
      final String cleaned = agentId?.trim() ?? '';
      if (cleaned.isNotEmpty) {
        final CommissionAccount? value = _accounts[cleaned];
        return value == null
            ? <CommissionAccount>[]
            : <CommissionAccount>[value];
      }
      final List<CommissionAccount> values = _accounts.values.toList();
      values.sort((a, b) => a.agentName.compareTo(b.agentName));
      return values;
    }

    yield current();
    yield* _changes.stream.map((_) => current());
  }

  @override
  Stream<List<AgentAssignmentMetric>> watchAssignmentMetrics({
    String? agentId,
  }) async* {
    List<AgentAssignmentMetric> current() => _filtered(
      _assignments,
      agentId,
      (AgentAssignmentMetric value) => value.agentId,
    );
    yield current();
    yield* _changes.stream.map((_) => current());
  }

  @override
  Stream<List<AgentProcessingMetric>> watchProcessingMetrics({
    String? agentId,
  }) async* {
    List<AgentProcessingMetric> current() => _filtered(
      _processingMetrics,
      agentId,
      (AgentProcessingMetric value) => value.agentId,
    );
    yield current();
    yield* _changes.stream.map((_) => current());
  }

  @override
  Stream<List<AgentOrderMetric>> watchOrderMetrics({String? agentId}) async* {
    List<AgentOrderMetric> current() => _filtered(
      _orderMetrics,
      agentId,
      (AgentOrderMetric value) => value.agentId,
    );
    yield current();
    yield* _changes.stream.map((_) => current());
  }

  @override
  Future<void> recordPayout({
    required String agentId,
    required String agentName,
    required int amount,
    required String paymentReference,
    required String staffId,
    required String staffName,
    String? note,
  }) async {
    final CommissionAccount? account = _accounts[agentId];
    if (account == null) {
      throw StateError('Aucune commission acquise pour cet agent.');
    }
    if (amount <= 0 || amount > account.balance) {
      throw StateError('Montant de paiement invalide.');
    }
    final String cleanedReference = paymentReference.trim().toUpperCase();
    if (cleanedReference.length < 3) {
      throw ArgumentError('Saisissez la référence du paiement Wave.');
    }
    if (_payouts.any(
      (CommissionPayout value) =>
          value.paymentReference.trim().toUpperCase() == cleanedReference,
    )) {
      throw StateError('Cette référence Wave a déjà été enregistrée.');
    }
    final DateTime now = DateTime.now();
    _payouts.add(
      CommissionPayout(
        id: 'payout-${_payouts.length + 1}',
        agentId: agentId,
        agentName: account.agentName,
        amount: amount,
        paymentChannel: 'wave',
        paymentReference: cleanedReference,
        paidAt: now,
        createdBy: staffId,
        createdByName: staffName,
        note: (note?.trim().isEmpty ?? true) ? null : note!.trim(),
      ),
    );
    _accounts[agentId] = CommissionAccount(
      agentId: account.agentId,
      agentName: account.agentName,
      earnedTotal: account.earnedTotal,
      paidTotal: account.paidTotal + amount,
      earnedTransactions: account.earnedTransactions,
      updatedAt: now,
    );
    _emit();
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
