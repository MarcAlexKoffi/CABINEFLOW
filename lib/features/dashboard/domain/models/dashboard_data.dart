enum ServiceChannel { orange, mtn, moov, wave }

enum PriorityOrderStatus { urgent, pendingVerification, inProgress }

class DashboardStatistics {
  const DashboardStatistics({
    required this.newRequests,
    required this.paymentsToVerify,
    required this.inProgress,
    required this.completed,
  });

  final int newRequests;
  final int paymentsToVerify;
  final int inProgress;
  final int completed;
}

class AccountBalance {
  const AccountBalance({required this.channel, required this.amount});

  final ServiceChannel channel;
  final int amount;
}

class PriorityOrder {
  const PriorityOrder({
    required this.reference,
    required this.phoneNumber,
    required this.operationLabel,
    required this.amount,
    required this.channel,
    required this.status,
    required this.actionLabel,
  });

  final String reference;
  final String phoneNumber;
  final String operationLabel;
  final int amount;
  final ServiceChannel channel;
  final PriorityOrderStatus status;
  final String actionLabel;
}

class DashboardData {
  const DashboardData({
    required this.ordersToProcess,
    required this.averageWaitingMinutes,
    required this.statistics,
    required this.balances,
    required this.priorityOrders,
  });

  final int ordersToProcess;
  final int averageWaitingMinutes;
  final DashboardStatistics statistics;
  final List<AccountBalance> balances;
  final List<PriorityOrder> priorityOrders;
}
