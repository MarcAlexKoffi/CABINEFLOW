import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  AppUser? _currentUser;

  @override
  Future<AuthLoginResult> login({
    required String identifier,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 1));

    final String normalizedIdentifier = identifier.trim().toLowerCase();

    final bool isAdminIdentifier =
        normalizedIdentifier == 'marc@cabineflow.app' ||
        normalizedIdentifier == 'marc';
    final bool isAgentIdentifier =
        normalizedIdentifier == 'agent@cabineflow.app' ||
        normalizedIdentifier == 'agent';

    final bool isValidPassword = password == '1234';

    if ((!isAdminIdentifier && !isAgentIdentifier) || !isValidPassword) {
      return const AuthLoginResult.invalidCredentials();
    }

    _currentUser = isAgentIdentifier
        ? const AppUser(
            id: 'AGENT-001',
            name: 'Koffi Kouassi',
            phoneNumber: '0700000001',
            role: UserRole.agent,
          )
        : const AppUser(
            id: 'USR-001',
            name: 'Marc Alex',
            phoneNumber: '0700000000',
            role: UserRole.administrator,
          );

    return AuthLoginResult.authenticated(_currentUser!);
  }

  @override
  Future<AuthLoginResult> refreshCurrentAccess() async {
    final AppUser? currentUser = _currentUser;

    if (currentUser == null) {
      return const AuthLoginResult.unavailable(
        message: 'Aucune session fictive n’est ouverte.',
      );
    }

    return AuthLoginResult.authenticated(currentUser);
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
  }
}
