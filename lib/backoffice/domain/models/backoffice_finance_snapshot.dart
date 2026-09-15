class BackofficeFinanceSnapshot {
  const BackofficeFinanceSnapshot({
    required this.generatedAt,
    required this.waveOpening,
    required this.waveAdjustments,
    required this.credits,
    required this.creditSettlements,
    required this.expenses,
    required this.closings,
    required this.suppliers,
    required this.supplierAccounts,
    required this.supplierRecharges,
    required this.supplierPayments,
    required this.commissionAccounts,
    required this.commissions,
    required this.commissionPayouts,
    required this.agentCapacities,
    required this.networkMovements,
    required this.orderPayments,
    required this.refunds,
    required this.orders,
    required this.successFinalizations,
    required this.ledgerEvents,
    required this.auditEvents,
  });

  final DateTime? generatedAt;
  final Map<String, dynamic>? waveOpening;
  final List<Map<String, dynamic>> waveAdjustments;
  final List<Map<String, dynamic>> credits;
  final List<Map<String, dynamic>> creditSettlements;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> closings;
  final List<Map<String, dynamic>> suppliers;
  final List<Map<String, dynamic>> supplierAccounts;
  final List<Map<String, dynamic>> supplierRecharges;
  final List<Map<String, dynamic>> supplierPayments;
  final List<Map<String, dynamic>> commissionAccounts;
  final List<Map<String, dynamic>> commissions;
  final List<Map<String, dynamic>> commissionPayouts;
  final List<Map<String, dynamic>> agentCapacities;
  final List<Map<String, dynamic>> networkMovements;
  final List<Map<String, dynamic>> orderPayments;
  final List<Map<String, dynamic>> refunds;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> successFinalizations;
  final List<Map<String, dynamic>> ledgerEvents;
  final List<Map<String, dynamic>> auditEvents;

  factory BackofficeFinanceSnapshot.fromJson(Map<String, dynamic> json) {
    return BackofficeFinanceSnapshot(
      generatedAt: financeDate(json['generated_at']),
      waveOpening: financeMap(json['wave_opening']),
      waveAdjustments: financeRows(json['wave_adjustments']),
      credits: financeRows(json['credits']),
      creditSettlements: financeRows(json['credit_settlements']),
      expenses: financeRows(json['expenses']),
      closings: financeRows(json['closings']),
      suppliers: financeRows(json['suppliers']),
      supplierAccounts: financeRows(json['supplier_accounts']),
      supplierRecharges: financeRows(json['supplier_recharges']),
      supplierPayments: financeRows(json['supplier_payments']),
      commissionAccounts: financeRows(json['commission_accounts']),
      commissions: financeRows(json['commissions']),
      commissionPayouts: financeRows(json['commission_payouts']),
      agentCapacities: financeRows(json['agent_capacities']),
      networkMovements: financeRows(json['network_movements']),
      orderPayments: financeRows(json['order_payments']),
      refunds: financeRows(json['refunds']),
      orders: financeRows(json['orders']),
      successFinalizations: financeRows(json['success_finalizations']),
      ledgerEvents: financeRows(json['ledger_events']),
      auditEvents: financeRows(json['audit_events']),
    );
  }

  bool get hasWaveOpening => waveOpening != null;

  int get openingWaveBalance => financeInt(waveOpening?['opening_balance']);

  DateTime? get waveOpeningEffectiveAt => financeDate(waveOpening?['effective_at']);

  int get customerReceivables => credits.fold<int>(
        0,
        (int total, Map<String, dynamic> row) =>
            total +
            _positive(financeInt(row['amount']) - financeInt(row['paid_amount'])),
      );

  int get supplierDebt => supplierAccounts.fold<int>(
        0,
        (int total, Map<String, dynamic> row) =>
            total +
            _positive(financeInt(row['total_owed']) - financeInt(row['total_paid'])),
      );

  int get commissionDebt => commissionAccounts.fold<int>(
        0,
        (int total, Map<String, dynamic> row) =>
            total +
            _positive(financeInt(row['earned_total']) - financeInt(row['paid_total'])),
      );

  int get totalAvailableCapacity => agentCapacities.fold<int>(
        0,
        (int total, Map<String, dynamic> row) =>
            total +
            financeInt(row['orange_capacity']) +
            financeInt(row['mtn_capacity']) +
            financeInt(row['moov_capacity']),
      );

  int capacityFor(String network) {
    final String key = '${network.toLowerCase()}_capacity';
    return agentCapacities.fold<int>(
      0,
      (int total, Map<String, dynamic> row) => total + financeInt(row[key]),
    );
  }

  /// Montant réservé par les commandes financées qui sont déjà affectées et
  /// encore en traitement. Une commande terminée/échouée ne bloque plus de
  /// capacité dans le fonds de roulement.
  int committedFor(String network) {
    final String normalized = network.toLowerCase();
    return orders.where((Map<String, dynamic> row) {
      if (financeString(row['network']) != normalized) {
        return false;
      }
      if (financeString(row['assigned_agent_id']).isEmpty) {
        return false;
      }
      if (!<String>{'confirmed', 'credit'}.contains(financeString(row['payment_status']))) {
        return false;
      }
      return <String>{'paidReady', 'inProgress', 'onHold'}
          .contains(financeString(row['order_status']));
    }).fold<int>(
      0,
      (int total, Map<String, dynamic> row) => total + financeInt(row['amount']),
    );
  }

  int freeCapacityFor(String network) {
    return _positive(capacityFor(network) - committedFor(network));
  }

  int get totalCommittedCapacity =>
      committedFor('orange') + committedFor('mtn') + committedFor('moov');

  int get totalFreeCapacity =>
      freeCapacityFor('orange') + freeCapacityFor('mtn') + freeCapacityFor('moov');

  int get operatingLiquidity => waveTheoreticalBalance + totalFreeCapacity;

  int get netWorkingCapital =>
      operatingLiquidity + customerReceivables - supplierDebt - commissionDebt;

  int successfulOrdersAmountOn(DateTime day) {
    return _successfulNetworkMovementsOn(day).fold<int>(
      0,
      (int total, Map<String, dynamic> row) => total + financeInt(row['amount']),
    );
  }

  int successfulOrdersCountOn(DateTime day) => _successfulNetworkMovementsOn(day).length;

  List<Map<String, dynamic>> _successfulNetworkMovementsOn(DateTime day) {
    return networkMovements.where((Map<String, dynamic> row) {
      return financeString(row['direction']) == 'outgoing' &&
          financeString(row['movement_type']) == 'orderSuccess' &&
          financeSameDay(financeDate(row['occurred_at']), day);
    }).toList(growable: false);
  }

  /// Encaissements de commandes confirmées. On lit la commande canonique,
  /// pas chaque évènement du ledger paiement, afin de ne jamais compter deux
  /// fois une même commande lorsque l'historique contient plusieurs évènements.
  int confirmedReceiptsOn(DateTime day) {
    return orders.where((Map<String, dynamic> row) {
      if (financeString(row['payment_status']) != 'confirmed') {
        return false;
      }
      final DateTime? at =
          financeDate(row['payment_confirmed_at']) ?? financeDate(row['paid_at']);
      return financeSameDay(at, day);
    }).fold<int>(
      0,
      (int total, Map<String, dynamic> row) => total + financeInt(row['amount']),
    );
  }

  int creditSettlementsOn(DateTime day, {String? channel}) {
    return creditSettlements.where((Map<String, dynamic> row) {
      if (!financeSameDay(financeDate(row['paid_at']), day)) {
        return false;
      }
      return channel == null || financeString(row['payment_channel']) == channel;
    }).fold<int>(
      0,
      (int total, Map<String, dynamic> row) => total + financeInt(row['amount']),
    );
  }

  int supplierPaymentsOn(DateTime day, {String? channel}) {
    return supplierPayments.where((Map<String, dynamic> row) {
      if (!financeSameDay(financeDate(row['paid_at']), day)) {
        return false;
      }
      return channel == null || financeString(row['payment_channel']) == channel;
    }).fold<int>(
      0,
      (int total, Map<String, dynamic> row) => total + financeInt(row['amount']),
    );
  }

  int expensesOn(DateTime day, {String? channel}) {
    return expenses.where((Map<String, dynamic> row) {
      if (!financeSameDay(financeDate(row['spent_at']), day)) {
        return false;
      }
      return channel == null || financeString(row['payment_channel']) == channel;
    }).fold<int>(
      0,
      (int total, Map<String, dynamic> row) => total + financeInt(row['amount']),
    );
  }

  int refundsOn(DateTime day) {
    return refunds.where((Map<String, dynamic> row) {
      return financeSameDay(financeDate(row['refunded_at']), day);
    }).fold<int>(
      0,
      (int total, Map<String, dynamic> row) => total + financeInt(row['amount']),
    );
  }

  int commissionEarnedOn(DateTime day) {
    return commissions.where((Map<String, dynamic> row) {
      return financeSameDay(financeDate(row['earned_at']), day);
    }).fold<int>(
      0,
      (int total, Map<String, dynamic> row) =>
          total + financeInt(row['commission_amount']),
    );
  }

  int commissionPaidOn(DateTime day, {String? channel}) {
    return commissionPayouts.where((Map<String, dynamic> row) {
      if (!financeSameDay(financeDate(row['paid_at']), day)) {
        return false;
      }
      return channel == null || financeString(row['payment_channel']) == channel;
    }).fold<int>(
      0,
      (int total, Map<String, dynamic> row) => total + financeInt(row['amount']),
    );
  }

  int supplierRechargeOn(DateTime day, String field) {
    return supplierRecharges.where((Map<String, dynamic> row) {
      return financeSameDay(financeDate(row['occurred_at']), day);
    }).fold<int>(
      0,
      (int total, Map<String, dynamic> row) => total + financeInt(row[field]),
    );
  }

  int creditsCreatedOn(DateTime day) {
    return credits.where((Map<String, dynamic> row) {
      return financeSameDay(financeDate(row['created_at']), day);
    }).fold<int>(
      0,
      (int total, Map<String, dynamic> row) => total + financeInt(row['amount']),
    );
  }

  int get waveClientPaymentsSinceOpening => _sumSince(
        orders,
        dateOf: (Map<String, dynamic> row) =>
            financeDate(row['payment_confirmed_at']) ?? financeDate(row['paid_at']),
        amountOf: (Map<String, dynamic> row) => financeInt(row['amount']),
        predicate: (Map<String, dynamic> row) =>
            financeString(row['payment_status']) == 'confirmed',
      );

  int get waveCreditSettlementsSinceOpening => _sumSince(
        creditSettlements,
        dateOf: (Map<String, dynamic> row) => financeDate(row['paid_at']),
        amountOf: (Map<String, dynamic> row) => financeInt(row['amount']),
        predicate: (Map<String, dynamic> row) =>
            financeString(row['payment_channel']) == 'wave',
      );

  int get waveSupplierPaymentsSinceOpening => _sumSince(
        supplierPayments,
        dateOf: (Map<String, dynamic> row) => financeDate(row['paid_at']),
        amountOf: (Map<String, dynamic> row) => financeInt(row['amount']),
        predicate: (Map<String, dynamic> row) =>
            financeString(row['payment_channel']) == 'wave',
      );

  int get waveExpensesSinceOpening => _sumSince(
        expenses,
        dateOf: (Map<String, dynamic> row) => financeDate(row['spent_at']),
        amountOf: (Map<String, dynamic> row) => financeInt(row['amount']),
        predicate: (Map<String, dynamic> row) =>
            financeString(row['payment_channel']) == 'wave',
      );

  int get waveRefundsSinceOpening => _sumSince(
        refunds,
        dateOf: (Map<String, dynamic> row) => financeDate(row['refunded_at']),
        amountOf: (Map<String, dynamic> row) => financeInt(row['amount']),
        predicate: (Map<String, dynamic> row) =>
            financeString(row['payment_channel']).isEmpty ||
            financeString(row['payment_channel']) == 'wave',
      );

  int get waveCommissionPayoutsSinceOpening => _sumSince(
        commissionPayouts,
        dateOf: (Map<String, dynamic> row) => financeDate(row['paid_at']),
        amountOf: (Map<String, dynamic> row) => financeInt(row['amount']),
        predicate: (Map<String, dynamic> row) =>
            financeString(row['payment_channel']).isEmpty ||
            financeString(row['payment_channel']) == 'wave',
      );

  int get waveIncomingSinceOpening =>
      waveClientPaymentsSinceOpening + waveCreditSettlementsSinceOpening;

  int get waveOutgoingSinceOpening =>
      waveSupplierPaymentsSinceOpening +
      waveExpensesSinceOpening +
      waveRefundsSinceOpening +
      waveCommissionPayoutsSinceOpening;

  int get waveTheoreticalBalance =>
      openingWaveBalance + waveIncomingSinceOpening - waveOutgoingSinceOpening;

  /// Conservé comme API de présentation pour la clôture du jour. Le solde Wave
  /// reste calculé depuis le dernier point de départ réel, pas depuis minuit.
  int waveTheoreticalBalanceOn(DateTime day) => waveTheoreticalBalance;

  int estimatedOperationalResultOn(DateTime day) {
    final List<Map<String, dynamic>> successes = _successfulNetworkMovementsOn(day);
    final Map<String, int> received = <String, int>{
      'orange': 0,
      'mtn': 0,
      'moov': 0,
    };
    final Map<String, int> cost = <String, int>{
      'orange': 0,
      'mtn': 0,
      'moov': 0,
    };
    for (final Map<String, dynamic> row in supplierRecharges) {
      final String network = financeString(row['network']);
      if (!received.containsKey(network)) {
        continue;
      }
      received[network] = received[network]! + financeInt(row['received_amount']);
      cost[network] = cost[network]! + financeInt(row['principal_amount']);
    }

    int turnover = 0;
    int estimatedNetworkCost = 0;
    for (final Map<String, dynamic> row in successes) {
      final String network = financeString(row['network']);
      final int amount = financeInt(row['amount']);
      turnover += amount;
      final int networkReceived = received[network] ?? 0;
      final int networkCost = cost[network] ?? 0;
      final double ratio = networkReceived <= 0
          ? 1
          : (networkCost / networkReceived).clamp(0, 1).toDouble();
      estimatedNetworkCost += (amount * ratio).round();
    }

    final Set<String> historicallySuccessfulOrders = networkMovements
        .where((Map<String, dynamic> row) {
          return financeString(row['movement_type']) == 'orderSuccess' &&
              financeString(row['order_id']).isNotEmpty;
        })
        .map((Map<String, dynamic> row) => financeString(row['order_id']))
        .toSet();
    final int profitRefunds = refunds.where((Map<String, dynamic> row) {
      return financeSameDay(financeDate(row['refunded_at']), day) &&
          historicallySuccessfulOrders.contains(financeString(row['order_id']));
    }).fold<int>(
      0,
      (int total, Map<String, dynamic> row) => total + financeInt(row['amount']),
    );

    final int grossMargin = turnover - estimatedNetworkCost;
    return grossMargin -
        commissionEarnedOn(day) -
        expensesOn(day) -
        profitRefunds;
  }

  int _sumSince(
    List<Map<String, dynamic>> source, {
    required DateTime? Function(Map<String, dynamic> row) dateOf,
    required int Function(Map<String, dynamic> row) amountOf,
    bool Function(Map<String, dynamic> row)? predicate,
  }) {
    final DateTime? effectiveAt = waveOpeningEffectiveAt;
    return source.where((Map<String, dynamic> row) {
      if (predicate != null && !predicate(row)) {
        return false;
      }
      final DateTime? at = dateOf(row);
      if (at == null) {
        return false;
      }
      return effectiveAt == null || !at.isBefore(effectiveAt);
    }).fold<int>(
      0,
      (int total, Map<String, dynamic> row) => total + amountOf(row),
    );
  }

  static int _positive(int value) => value < 0 ? 0 : value;
}

List<Map<String, dynamic>> financeRows(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return List<Map<String, dynamic>>.unmodifiable(<Map<String, dynamic>>[
    for (final Object? item in value)
      if (item is Map<String, dynamic>)
        Map<String, dynamic>.unmodifiable(item)
      else if (item is Map)
        Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(item)),
  ]);
}

Map<String, dynamic>? financeMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(value);
  }
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(value));
  }
  return null;
}

int financeInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String financeString(Object? value) => value?.toString().trim() ?? '';

DateTime? financeDate(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}

bool financeSameDay(DateTime? value, DateTime day) {
  if (value == null) {
    return false;
  }
  final DateTime local = value.toLocal();
  return local.year == day.year &&
      local.month == day.month &&
      local.day == day.day;
}
