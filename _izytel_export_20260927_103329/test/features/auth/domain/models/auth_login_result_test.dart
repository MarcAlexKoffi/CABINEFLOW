import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthLoginResult', () {
    test('authenticated expose un utilisateur autorisé', () {
      const AppUser user = AppUser(
        id: 'USR-001',
        name: 'Marc Alex',
        phoneNumber: '0700000000',
        role: UserRole.administrator,
      );

      final AuthLoginResult result = AuthLoginResult.authenticated(user);

      expect(result.status, AuthLoginStatus.authenticated);
      expect(result.isAuthenticated, isTrue);
      expect(result.requiresAccessScreen, isFalse);
      expect(result.user, same(user));
    });

    test('pendingActivation demande l’écran d’attente', () {
      final AuthLoginResult result = AuthLoginResult.pendingActivation(
        profileName: 'Jean Koffi',
        email: 'jean@cabineflow.app',
      );

      expect(result.status, AuthLoginStatus.pendingActivation);
      expect(result.isAuthenticated, isFalse);
      expect(result.requiresAccessScreen, isTrue);
    });

    test('inactive demande aussi l’écran de contrôle d’accès', () {
      final AuthLoginResult result = AuthLoginResult.inactive(
        profileName: 'Jean Koffi',
        email: 'jean@cabineflow.app',
      );

      expect(result.status, AuthLoginStatus.inactive);
      expect(result.isAuthenticated, isFalse);
      expect(result.requiresAccessScreen, isTrue);
    });
  });
}
