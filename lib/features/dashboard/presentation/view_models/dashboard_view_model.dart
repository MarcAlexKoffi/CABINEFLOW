import 'package:cabine_flow/features/dashboard/domain/models/dashboard_data.dart';
import 'package:cabine_flow/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:flutter/foundation.dart';

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({required DashboardRepository dashboardRepository})
    : _dashboardRepository = dashboardRepository;

  final DashboardRepository _dashboardRepository;

  bool _isLoading = false;
  String? _errorMessage;
  DashboardData? _dashboardData;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  DashboardData? get dashboardData => _dashboardData;

  Future<void> loadDashboard() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      _dashboardData = await _dashboardRepository.fetchDashboardData();
    } catch (_) {
      _errorMessage = 'Impossible de charger le tableau de bord.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
