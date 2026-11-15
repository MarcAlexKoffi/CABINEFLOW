enum CommissionV2Period { all, today, last7Days, thisMonth }

enum CommissionHistoryKind { all, commissions, payouts }

enum CommissionSettlementState { all, unpaid, partial, paid, empty }

class CommissionV2Entry {
  const CommissionV2Entry({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.agentId,
    required this.agentName,
    required this.network,
    required this.orderAmount,
    required this.commissionAmount,
    required this.policyId,
    required this.policyType,
    required this.rate,
    required this.earnedAt,
  });

  final String id;
  final String orderId;
  final String orderReference;
  final String agentId;
  final String agentName;
  final String network;
  final int orderAmount;
  final int commissionAmount;
  final String policyId;
  final String policyType;
  final int rate;
  final DateTime earnedAt;

  bool matchesQuery(String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    return _matchesAny(normalizedQuery, <String>[
      id,
      orderId,
      orderReference,
      agentId,
      agentName,
      network,
      '$orderAmount',
      '$commissionAmount',
    ]);
  }
}

class CommissionPayoutV2Entry {
  const CommissionPayoutV2Entry({
    required this.id,
    required this.agentId,
    required this.agentName,
    required this.amount,
    required this.paymentChannel,
    required this.paymentReference,
    required this.paidAt,
    this.note,
    this.createdByName,
  });

  final String id;
  final String agentId;
  final String agentName;
  final int amount;
  final String paymentChannel;
  final String paymentReference;
  final DateTime paidAt;
  final String? note;
  final String? createdByName;

  bool matchesQuery(String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    return _matchesAny(normalizedQuery, <String>[
      id,
      agentId,
      agentName,
      paymentChannel,
      paymentReference,
      note ?? '',
      createdByName ?? '',
      '$amount',
    ]);
  }
}

class CommissionAccountV2 {
  const CommissionAccountV2({
    required this.agentId,
    required this.agentName,
    required this.earnedTotal,
    required this.paidTotal,
    required this.earnedTransactions,
    this.lastCommissionOrderId,
    this.lastPayoutId,
    this.updatedAt,
  });

  final String agentId;
  final String agentName;
  final int earnedTotal;
  final int paidTotal;
  final int earnedTransactions;
  final String? lastCommissionOrderId;
  final String? lastPayoutId;
  final DateTime? updatedAt;

  int get outstanding => earnedTotal - paidTotal;

  CommissionSettlementState get settlementState {
    if (earnedTotal <= 0) return CommissionSettlementState.empty;
    if (paidTotal <= 0) return CommissionSettlementState.unpaid;
    if (paidTotal < earnedTotal) return CommissionSettlementState.partial;
    return CommissionSettlementState.paid;
  }

  bool matchesQuery(String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    return _matchesAny(normalizedQuery, <String>[
      agentId,
      agentName,
      lastCommissionOrderId ?? '',
      lastPayoutId ?? '',
      '$earnedTotal',
      '$paidTotal',
      '$earnedTransactions',
    ]);
  }
}

class CommissionV2Filter {
  const CommissionV2Filter({
    this.period = CommissionV2Period.thisMonth,
    this.historyKind = CommissionHistoryKind.all,
    this.settlementState = CommissionSettlementState.all,
    this.network,
    this.query = '',
  });

  final CommissionV2Period period;
  final CommissionHistoryKind historyKind;
  final CommissionSettlementState settlementState;
  final String? network;
  final String query;

  CommissionV2Filter copyWith({
    CommissionV2Period? period,
    CommissionHistoryKind? historyKind,
    CommissionSettlementState? settlementState,
    String? network,
    bool clearNetwork = false,
    String? query,
  }) {
    return CommissionV2Filter(
      period: period ?? this.period,
      historyKind: historyKind ?? this.historyKind,
      settlementState: settlementState ?? this.settlementState,
      network: clearNetwork ? null : network ?? this.network,
      query: query ?? this.query,
    );
  }
}

class CommissionHistoryItemV2 {
  const CommissionHistoryItemV2._({
    required this.id,
    required this.agentId,
    required this.agentName,
    required this.date,
    required this.amount,
    required this.kind,
    required this.title,
    required this.reference,
    this.network,
    this.subtitle,
  });

  factory CommissionHistoryItemV2.commission(CommissionV2Entry entry) {
    return CommissionHistoryItemV2._(
      id: entry.id,
      agentId: entry.agentId,
      agentName: entry.agentName,
      date: entry.earnedAt,
      amount: entry.commissionAmount,
      kind: CommissionHistoryKind.commissions,
      title: 'Commission gagnée',
      reference: entry.orderReference.isEmpty
          ? entry.orderId
          : entry.orderReference,
      network: entry.network,
      subtitle: 'Commande ${entry.orderAmount} F CFA',
    );
  }

  factory CommissionHistoryItemV2.payout(CommissionPayoutV2Entry entry) {
    return CommissionHistoryItemV2._(
      id: entry.id,
      agentId: entry.agentId,
      agentName: entry.agentName,
      date: entry.paidAt,
      amount: entry.amount,
      kind: CommissionHistoryKind.payouts,
      title: 'Versement enregistré',
      reference: entry.paymentReference,
      subtitle: entry.note,
    );
  }

  final String id;
  final String agentId;
  final String agentName;
  final DateTime date;
  final int amount;
  final CommissionHistoryKind kind;
  final String title;
  final String reference;
  final String? network;
  final String? subtitle;
}

class CommissionNetworkStatV2 {
  const CommissionNetworkStatV2({
    required this.network,
    required this.amount,
    required this.transactions,
  });

  final String network;
  final int amount;
  final int transactions;
}

class CommissionV2Stats {
  const CommissionV2Stats({
    required this.generatedAmount,
    required this.commissionCount,
    required this.payoutCount,
    required this.networks,
    this.paidAmount,
    this.currentOutstanding,
  });

  final int generatedAmount;
  final int commissionCount;
  final int payoutCount;

  /// Null when a network filter is active. Existing payouts are account-level
  /// and do not carry a network allocation, so D deliberately does not invent
  /// a per-network paid amount.
  final int? paidAmount;

  /// Null when a network filter is active for the same reason as [paidAmount].
  final int? currentOutstanding;

  final List<CommissionNetworkStatV2> networks;
}

class CommissionV2View {
  const CommissionV2View({
    required this.commissions,
    required this.payouts,
    required this.accounts,
    required this.timeline,
    required this.stats,
  });

  final List<CommissionV2Entry> commissions;
  final List<CommissionPayoutV2Entry> payouts;
  final List<CommissionAccountV2> accounts;
  final List<CommissionHistoryItemV2> timeline;
  final CommissionV2Stats stats;
}

class CommissionV2Snapshot {
  const CommissionV2Snapshot({
    required this.commissions,
    required this.payouts,
    required this.accounts,
  });

  final List<CommissionV2Entry> commissions;
  final List<CommissionPayoutV2Entry> payouts;
  final List<CommissionAccountV2> accounts;

  CommissionV2View apply(CommissionV2Filter filter, {DateTime? now}) {
    final DateTime clock = now ?? DateTime.now();
    final String normalizedQuery = filter.query.trim().toLowerCase();
    final DateTime? start = _periodStart(filter.period, clock);
    final String? network = _normalizeNetwork(filter.network);

    final List<CommissionAccountV2> settlementEligibleAccounts = accounts.where((account) {
      return filter.settlementState == CommissionSettlementState.all ||
          account.settlementState == filter.settlementState;
    }).toList(growable: false);

    final Set<String>? settlementAgentIds =
        filter.settlementState == CommissionSettlementState.all
        ? null
        : settlementEligibleAccounts.map((account) => account.agentId).toSet();

    final List<CommissionV2Entry> filteredCommissions = commissions.where((entry) {
      if (!_isInPeriod(entry.earnedAt, start, clock)) return false;
      if (network != null && entry.network.toLowerCase() != network) return false;
      if (settlementAgentIds != null && !settlementAgentIds.contains(entry.agentId)) {
        return false;
      }
      return entry.matchesQuery(normalizedQuery);
    }).toList(growable: false)
      ..sort((a, b) => b.earnedAt.compareTo(a.earnedAt));

    final List<CommissionPayoutV2Entry> filteredPayouts = payouts.where((entry) {
      if (!_isInPeriod(entry.paidAt, start, clock)) return false;
      if (settlementAgentIds != null && !settlementAgentIds.contains(entry.agentId)) {
        return false;
      }
      return entry.matchesQuery(normalizedQuery);
    }).toList(growable: false)
      ..sort((a, b) => b.paidAt.compareTo(a.paidAt));

    final Set<String> queryMatchedAgentIds = <String>{
      for (final CommissionV2Entry entry in filteredCommissions) entry.agentId,
      for (final CommissionPayoutV2Entry entry in filteredPayouts) entry.agentId,
    };

    final List<CommissionAccountV2> filteredAccounts = settlementEligibleAccounts
        .where((account) {
          if (normalizedQuery.isEmpty) return true;
          return account.matchesQuery(normalizedQuery) ||
              queryMatchedAgentIds.contains(account.agentId);
        })
        .toList(growable: false)
      ..sort((a, b) {
        final int outstandingComparison = b.outstanding.compareTo(a.outstanding);
        if (outstandingComparison != 0) return outstandingComparison;
        return a.agentName.toLowerCase().compareTo(b.agentName.toLowerCase());
      });

    final List<CommissionHistoryItemV2> timeline = <CommissionHistoryItemV2>[];
    if (filter.historyKind != CommissionHistoryKind.payouts) {
      timeline.addAll(filteredCommissions.map(CommissionHistoryItemV2.commission));
    }
    if (filter.historyKind != CommissionHistoryKind.commissions && network == null) {
      timeline.addAll(filteredPayouts.map(CommissionHistoryItemV2.payout));
    }
    timeline.sort((a, b) => b.date.compareTo(a.date));

    final Map<String, List<CommissionV2Entry>> byNetwork =
        <String, List<CommissionV2Entry>>{};
    for (final CommissionV2Entry commission in filteredCommissions) {
      final String key = commission.network.toLowerCase();
      (byNetwork[key] ??= <CommissionV2Entry>[]).add(commission);
    }

    final List<CommissionNetworkStatV2> networkStats = <String>[
      'orange',
      'mtn',
      'moov',
    ].map((key) {
      final List<CommissionV2Entry> entries = byNetwork[key] ?? const <CommissionV2Entry>[];
      return CommissionNetworkStatV2(
        network: key,
        amount: entries.fold<int>(0, (total, item) => total + item.commissionAmount),
        transactions: entries.length,
      );
    }).toList(growable: false);

    final int generated = filteredCommissions.fold<int>(
      0,
      (total, item) => total + item.commissionAmount,
    );
    final int paid = filteredPayouts.fold<int>(
      0,
      (total, item) => total + item.amount,
    );
    final int outstanding = filteredAccounts.fold<int>(
      0,
      (total, account) => total + account.outstanding,
    );

    return CommissionV2View(
      commissions: filteredCommissions,
      payouts: filteredPayouts,
      accounts: filteredAccounts,
      timeline: timeline,
      stats: CommissionV2Stats(
        generatedAmount: generated,
        paidAmount: network == null ? paid : null,
        currentOutstanding: network == null ? outstanding : null,
        commissionCount: filteredCommissions.length,
        payoutCount: network == null ? filteredPayouts.length : 0,
        networks: networkStats,
      ),
    );
  }
}

DateTime? _periodStart(CommissionV2Period period, DateTime now) {
  switch (period) {
    case CommissionV2Period.all:
      return null;
    case CommissionV2Period.today:
      return DateTime(now.year, now.month, now.day);
    case CommissionV2Period.last7Days:
      return DateTime(now.year, now.month, now.day).subtract(
        const Duration(days: 6),
      );
    case CommissionV2Period.thisMonth:
      return DateTime(now.year, now.month);
  }
}

bool _isInPeriod(DateTime value, DateTime? start, DateTime now) {
  if (start != null && value.isBefore(start)) return false;
  return !value.isAfter(now);
}

String? _normalizeNetwork(String? network) {
  final String value = (network ?? '').trim().toLowerCase();
  return value.isEmpty ? null : value;
}

bool _matchesAny(String normalizedQuery, Iterable<String> values) {
  for (final String value in values) {
    if (value.toLowerCase().contains(normalizedQuery)) return true;
  }
  return false;
}
