import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'l’administration expose une vraie déconnexion avec nettoyage de navigation',
    () {
      final String source = File(
        'lib/features/more/presentation/pages/more_page.dart',
      ).readAsStringSync();

      expect(source, contains("'Se déconnecter'"));
      expect(source, contains('await authRepository.logout()'));
      expect(source, contains('pushNamedAndRemoveUntil'));
      expect(source, contains('AppRoutes.login'));
    },
  );
}
