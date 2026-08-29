import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'l’espace Agent expose une déconnexion réelle et nettoie la navigation',
    () {
      final String app = File('lib/app/app.dart').readAsStringSync();
      final String shell = File(
        'lib/features/navigation/presentation/pages/main_shell_page.dart',
      ).readAsStringSync();
      final String profile = File(
        'lib/features/agents/presentation/pages/agent_activity_page.dart',
      ).readAsStringSync();

      expect(app, contains('authRepository: effectiveAuthRepository'));
      expect(shell, contains('await widget.authRepository.logout()'));
      expect(shell, contains('pushNamedAndRemoveUntil'));
      expect(shell, contains('AppRoutes.login'));
      expect(profile, contains("'Se déconnecter'"));
      expect(profile, contains('onLogout'));
    },
  );
}
