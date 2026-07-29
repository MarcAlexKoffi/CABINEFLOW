import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter/foundation.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  bool _isLoading = false;
  String? _errorMessage;
  AppUser? _authenticatedUser;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  AppUser? get authenticatedUser => _authenticatedUser;

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    if (_isLoading) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _authenticatedUser = null;

    notifyListeners();

    try {
      final AppUser? user = await _authRepository.login(
        identifier: identifier,
        password: password,
      );

      if (user == null) {
        _errorMessage = 'Identifiant ou mot de passe incorrect.';
        return false;
      }

      _authenticatedUser = user;

      return true;
    } catch (_) {
      _errorMessage = 'Une erreur inattendue est survenue. Réessaie plus tard.';

      return false;
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
