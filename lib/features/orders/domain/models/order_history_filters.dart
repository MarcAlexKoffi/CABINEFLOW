import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

enum OrderHistoryPeriod { today, yesterday, last7Days, last30Days, all }

enum OrderHistoryStateFilter { active, completed, failed, expired }

class OrderHistoryFilters {
  const OrderHistoryFilters({
    this.period = OrderHistoryPeriod.all,
    this.states = const <OrderHistoryStateFilter>{},
    this.networks = const <MobileNetwork>{},
    this.minimumAmount,
    this.maximumAmount,
    this.operatorId,
  });

  final OrderHistoryPeriod period;
  final Set<OrderHistoryStateFilter> states;
  final Set<MobileNetwork> networks;
  final int? minimumAmount;
  final int? maximumAmount;
  final String? operatorId;

  bool get isEmpty {
    return period == OrderHistoryPeriod.all &&
        states.isEmpty &&
        networks.isEmpty &&
        minimumAmount == null &&
        maximumAmount == null &&
        (operatorId == null || operatorId!.trim().isEmpty);
  }

  int get activeFilterCount {
    int count = 0;

    if (period != OrderHistoryPeriod.all) {
      count++;
    }

    count += states.length;
    count += networks.length;

    if (minimumAmount != null || maximumAmount != null) {
      count++;
    }

    if (operatorId?.trim().isNotEmpty == true) {
      count++;
    }

    return count;
  }

  OrderHistoryFilters copyWith({
    OrderHistoryPeriod? period,
    Set<OrderHistoryStateFilter>? states,
    Set<MobileNetwork>? networks,
    int? minimumAmount,
    int? maximumAmount,
    String? operatorId,
    bool clearMinimumAmount = false,
    bool clearMaximumAmount = false,
    bool clearOperatorId = false,
  }) {
    return OrderHistoryFilters(
      period: period ?? this.period,
      states: states ?? this.states,
      networks: networks ?? this.networks,
      minimumAmount: clearMinimumAmount
          ? null
          : minimumAmount ?? this.minimumAmount,
      maximumAmount: clearMaximumAmount
          ? null
          : maximumAmount ?? this.maximumAmount,
      operatorId: clearOperatorId ? null : operatorId ?? this.operatorId,
    );
  }
}
