import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/features/dashboard/domain/models/dashboard_data.dart';
import 'package:cabine_flow/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:flutter/foundation.dart';

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({required DashboardRepository dashboardRepository})
    : _dashboardRepository = dashboardRepository;

  final DashboardRepository _dashboardRepository;
  StreamSubscription<DashboardData>? _subscription;

  bool _isLoading = false;
  String? _errorMessage;
  DashboardData? _dashboardData;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DashboardData? get dashboardData => _dashboardData;

  void startRealtime() {
    if (_subscription != null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _dashboardRepository.watchDashboardData().listen(
      (DashboardData data) {
        _dashboardData = data;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        IzyTelLog.backendError(
          'Dashboard.watch',
          error,
          stackTrace: stackTrace,
        );
        _isLoading = false;
        _errorMessage = 'Impossible de charger le tableau de bord.';
        notifyListeners();
      },
    );
  }

  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _dashboardData = await _dashboardRepository.fetchDashboardData();
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'Dashboard.load',
        error,
        stackTrace: stackTrace,
      );
      _errorMessage = 'Impossible de charger le tableau de bord.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
