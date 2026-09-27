import 'package:cabine_flow/features/dashboard/domain/models/dashboard_data.dart';
import 'package:cabine_flow/features/dashboard/domain/repositories/dashboard_repository.dart';

class FakeDashboardRepository implements DashboardRepository {
  const FakeDashboardRepository();

  @override
  Future<DashboardData> fetchDashboardData() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));

    return const DashboardData(
      ordersToProcess: 28,
      averageWaitingMinutes: 4,
      todayRevenue: 156000,
      revenueChangePercentage: 12,
      statistics: DashboardStatistics(
        newRequests: 8,
        paymentsToVerify: 3,
        inProgress: 5,
        completed: 42,
        unassignedOrders: 2,
      ),
      balances: <AccountBalance>[
        AccountBalance(channel: ServiceChannel.orange, amount: 35400),
        AccountBalance(channel: ServiceChannel.mtn, amount: 18500),
        AccountBalance(channel: ServiceChannel.moov, amount: 24850),
        AccountBalance(channel: ServiceChannel.wave, amount: 156000),
      ],
      priorityOrders: <PriorityOrder>[
        PriorityOrder(
          reference: 'ORD-9823',
          phoneNumber: '07 08 45 67 89',
          operationLabel: 'Dépôt Cash',
          amount: 25000,
          channel: ServiceChannel.orange,
          status: PriorityOrderStatus.urgent,
          actionLabel: 'Traiter',
        ),
        PriorityOrder(
          reference: 'ORD-9824',
          phoneNumber: '01 23 45 67 89',
          operationLabel: 'Retrait',
          amount: 10000,
          channel: ServiceChannel.wave,
          status: PriorityOrderStatus.pendingVerification,
          actionLabel: 'Vérifier',
        ),
        PriorityOrder(
          reference: 'ORD-9825',
          phoneNumber: '05 55 66 77 88',
          operationLabel: 'Achat Forfait',
          amount: 5000,
          channel: ServiceChannel.mtn,
          status: PriorityOrderStatus.inProgress,
          actionLabel: 'Ouvrir',
        ),
      ],
    );
  }

  @override
  Stream<DashboardData> watchDashboardData() async* {
    yield await fetchDashboardData();
  }
}
