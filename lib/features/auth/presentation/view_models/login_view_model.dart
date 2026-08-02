import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter/foundation.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  bool _isLoading = false;
  String? _errorMessage;
  AuthLoginResult? _loginResult;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  AuthLoginResult? get loginResult => _loginResult;

  Future<AuthLoginResult?> login({
    required String identifier,
    required String password,
  }) async {
    if (_isLoading) {
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    _loginResult = null;

    notifyListeners();

    try {
      final AuthLoginResult result = await _authRepository.login(
        identifier: identifier,
        password: password,
      );

      _loginResult = result;

      switch (result.status) {
        case AuthLoginStatus.authenticated:
        case AuthLoginStatus.pendingActivation:
        case AuthLoginStatus.inactive:
          return result;

        case AuthLoginStatus.invalidCredentials:
          _errorMessage =
              result.message ?? 'Adresse e-mail ou mot de passe incorrect.';
          return result;

        case AuthLoginStatus.unavailable:
          _errorMessage =
              result.message ??
              'Impossible de se connecter. Vérifie Internet puis réessaie.';
          return result;
      }
    } catch (_) {
      _errorMessage =
          'Impossible de se connecter. Vérifie Internet puis réessaie.';

      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }
}
