import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter/foundation.dart';

class PendingAccountViewModel extends ChangeNotifier {
  PendingAccountViewModel({
    required AuthRepository authRepository,
    required AuthLoginResult initialResult,
  }) : _authRepository = authRepository,
       _result = initialResult;

  final AuthRepository _authRepository;

  AuthLoginResult _result;
  bool _isRefreshing = false;
  bool _isSigningOut = false;
  String? _feedbackMessage;

  AuthLoginResult get result => _result;

  bool get isRefreshing => _isRefreshing;

  bool get isSigningOut => _isSigningOut;

  bool get isBusy => _isRefreshing || _isSigningOut;

  String? get feedbackMessage => _feedbackMessage;

  bool get isInactive {
    return _result.status == AuthLoginStatus.inactive;
  }

  String get profileName {
    final String value = _result.profileName?.trim() ?? '';
    return value.isEmpty ? 'Utilisateur IzyTel' : value;
  }

  String get email {
    return _result.email?.trim() ?? '';
  }

  Future<AppUser?> refreshAccess() async {
    if (isBusy) {
      return null;
    }

    _isRefreshing = true;
    _feedbackMessage = null;
    notifyListeners();

    try {
      final AuthLoginResult refreshedResult = await _authRepository
          .refreshCurrentAccess();

      if (refreshedResult.isAuthenticated && refreshedResult.user != null) {
        _result = refreshedResult;
        return refreshedResult.user;
      }

      if (refreshedResult.requiresAccessScreen) {
        _result = refreshedResult;
        _feedbackMessage =
            refreshedResult.status == AuthLoginStatus.pendingActivation
            ? 'Ton compte est toujours en attente d’activation.'
            : 'Ton compte est toujours inactif.';
      } else {
        _feedbackMessage =
            refreshedResult.message ??
            'Impossible de vérifier le compte pour le moment.';
      }

      return null;
    } catch (_) {
      _feedbackMessage =
          'Impossible de vérifier le compte. Contrôle ta connexion Internet.';
      return null;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<bool> logout() async {
    if (isBusy) {
      return false;
    }

    _isSigningOut = true;
    _feedbackMessage = null;
    notifyListeners();

    try {
      await _authRepository.logout();
      return true;
    } catch (_) {
      _feedbackMessage = 'Impossible de se déconnecter pour le moment.';
      return false;
    } finally {
      _isSigningOut = false;
      notifyListeners();
    }
  }
}
