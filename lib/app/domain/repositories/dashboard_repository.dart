import 'package:cabine_flow/app/domain/entities/dashboard/dashboard_data.dart';

abstract class DashboardRepository {
  Future<DashboardData> fetchDashboardData();

  Stream<DashboardData> watchDashboardData();
}
