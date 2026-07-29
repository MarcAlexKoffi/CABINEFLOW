import 'package:cabine_flow/features/dashboard/domain/models/dashboard_data.dart';

abstract class DashboardRepository {
  Future<DashboardData> fetchDashboardData();
}
