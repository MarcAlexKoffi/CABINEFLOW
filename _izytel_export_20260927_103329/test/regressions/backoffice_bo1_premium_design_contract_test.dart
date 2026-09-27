import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BO-1 - design premium clair IzyTel', () {
    test('le back-office reutilise la palette officielle du mobile', () {
      final String theme = File(
        'lib/backoffice/presentation/theme/backoffice_theme.dart',
      ).readAsStringSync();
      final String app = File(
        'lib/backoffice/backoffice_app.dart',
      ).readAsStringSync();

      expect(theme, contains('static const Color canvas = IzyTelColors.background'));
      expect(theme, contains('static const Color sidebar = IzyTelColors.surface'));
      expect(theme, contains('static const Color primary = IzyTelColors.primary'));
      expect(theme, contains('static const Color cyan = IzyTelColors.secondary'));
      expect(theme, contains('BackofficeGradients'));
      expect(app, contains('theme: BackofficeTheme.light'));
      expect(app, contains('themeMode: ThemeMode.light'));
    });

    test('navigation dashboard et utilisateurs restent bleu et blanc', () {
      final String shell = File(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      ).readAsStringSync();
      final String dashboard = File(
        'lib/backoffice/presentation/pages/backoffice_dashboard_page.dart',
      ).readAsStringSync();
      final String users = File(
        'lib/backoffice/presentation/pages/backoffice_users_page.dart',
      ).readAsStringSync();
      final String login = File(
        'lib/backoffice/presentation/pages/backoffice_login_page.dart',
      ).readAsStringSync();

      expect(shell, contains('BackofficeGradients.selectedNav'));
      expect(shell, contains('BackofficePalette.primarySoft'));
      expect(shell, contains('fill: selected ? 1 : 0'));
      expect(dashboard, contains('BackofficeGradients.hero'));
      expect(dashboard, contains('CENTRE DE PILOTAGE IZYTEL'));
      expect(users, contains("'ADMINISTRATION'"));
      expect(users, contains('backofficePanelDecoration'));
      expect(login, contains('BackofficeGradients.hero'));
    });
  });
}
