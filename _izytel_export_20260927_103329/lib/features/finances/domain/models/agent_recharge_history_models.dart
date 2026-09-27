import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';

class AgentRechargeHistoryFilter {
  const AgentRechargeHistoryFilter({
    this.network,
    this.searchQuery = '',
    this.from,
    this.to,
  });

  final AgentNetwork? network;
  final String searchQuery;
  final DateTime? from;
  final DateTime? to;

  bool get isActive =>
      network != null ||
      searchQuery.trim().isNotEmpty ||
      from != null ||
      to != null;

  AgentRechargeHistoryFilter copyWith({
    AgentNetwork? network,
    bool clearNetwork = false,
    String? searchQuery,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
  }) {
    return AgentRechargeHistoryFilter(
      network: clearNetwork ? null : network ?? this.network,
      searchQuery: searchQuery ?? this.searchQuery,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
    );
  }
}

class AgentRechargeHistoryCursor {
  const AgentRechargeHistoryCursor({
    required this.occurredAt,
    required this.rowId,
  });

  final DateTime occurredAt;
  final String rowId;
}

class AgentRechargeHistoryPageData {
  const AgentRechargeHistoryPageData({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<SupplierRecharge> items;
  final bool hasMore;
  final AgentRechargeHistoryCursor? nextCursor;
}

class AgentRechargeHistorySummary {
  const AgentRechargeHistorySummary({
    required this.totalCount,
    required this.totalReceived,
    required this.totalBonus,
  });

  final int totalCount;
  final int totalReceived;
  final int totalBonus;
}
