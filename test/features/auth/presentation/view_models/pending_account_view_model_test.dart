import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/features/auth/presentation/view_models/pending_account_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAuthRepository implements AuthRepository {
  _StubAuthRepository({required this.refreshResult});

  AuthLoginResult refreshResult;
  bool didLogout = false;

  @override
  Future<AuthLoginResult> login({
    required String identifier,
    required String password,
  }) async {
    return refreshResult;
  }

  @override
  Future<void> logout() async {
    didLogout = true;
  }

  @override
  Future<AuthLoginResult> refreshCurrentAccess() async {
    return refreshResult;
  }
}

void main() {
  group('PendingAccountViewModel', () {
    test('ouvre l’accès quand le profil devient actif', () async {
      final AuthLoginResult initialResult = AuthLoginResult.pendingActivation(
        profileName: 'Jean Koffi',
        email: 'jean@cabineflow.app',
      );

      const AppUser activeUser = AppUser(
        id: 'USR-002',
        name: 'Jean Koffi',
        phoneNumber: '0701020304',
        role: UserRole.operator,
      );

      final _StubAuthRepository repository = _StubAuthRepository(
        refreshResult: AuthLoginResult.authenticated(activeUser),
      );

      final PendingAccountViewModel viewModel = PendingAccountViewModel(
        authRepository: repository,
        initialResult: initialResult,
      );

      final AppUser? result = await viewModel.refreshAccess();

      expect(result, same(activeUser));
      expect(viewModel.result.isAuthenticated, isTrue);
    });

    test('reste en attente lorsque le rôle vaut pending', () async {
      final AuthLoginResult initialResult = AuthLoginResult.pendingActivation(
        profileName: 'Jean Koffi',
        email: 'jean@cabineflow.app',
      );

      final _StubAuthRepository repository = _StubAuthRepository(
        refreshResult: initialResult,
      );

      final PendingAccountViewModel viewModel = PendingAccountViewModel(
        authRepository: repository,
        initialResult: initialResult,
      );

      final AppUser? result = await viewModel.refreshAccess();

      expect(result, isNull);
      expect(
        viewModel.feedbackMessage,
        'Ton compte est toujours en attente d’activation.',
      );
    });

    test('déconnecte la session', () async {
      final AuthLoginResult initialResult = AuthLoginResult.pendingActivation(
        profileName: 'Jean Koffi',
        email: 'jean@cabineflow.app',
      );

      final _StubAuthRepository repository = _StubAuthRepository(
        refreshResult: initialResult,
      );

      final PendingAccountViewModel viewModel = PendingAccountViewModel(
        authRepository: repository,
        initialResult: initialResult,
      );

      final bool didLogout = await viewModel.logout();

      expect(didLogout, isTrue);
      expect(repository.didLogout, isTrue);
    });
  });
}
