import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('BO-7.1 - Design System Premium', () {
    test('le Back-office garde Manrope et une hiérarchie premium', () {
      final String appTheme = _read('lib/core/theme/app_theme.dart');
      final String theme = _read(
        'lib/backoffice/presentation/theme/backoffice_theme.dart',
      );

      expect(appTheme, contains('GoogleFonts.manropeTextTheme'));
      expect(theme, contains('fontSize: 36'));
      expect(theme, contains('fontSize: 32'));
      expect(theme, contains('fontSize: 26'));
      expect(theme, contains('BackofficeShadows'));
    });

    test('les badges réseaux utilisent les assets officiels existants', () {
      final String widgets = _read(
        'lib/backoffice/presentation/widgets/backoffice_order_widgets.dart',
      );
      final String operatorBrand = _read(
        'lib/shared/widgets/design_system/izy_tel_operator_brand.dart',
      );

      expect(operatorBrand, contains("orange_ci.png"));
      expect(operatorBrand, contains("mtn_ci.png"));
      expect(operatorBrand, contains("moov_africa_ci.png"));
      expect(widgets, contains('network.brandLogoAsset'));
      expect(widgets, contains('network.brandLabel'));
      expect(widgets, contains("assets/images/wave_logo.png"));
    });

    test('les pages partagent le nouveau header et les tableaux premium', () {
      final String widgets = _read(
        'lib/backoffice/presentation/widgets/backoffice_order_widgets.dart',
      );

      expect(widgets, contains('BackofficePageIntro'));
      expect(widgets, contains('BackofficeGradients.brand'));
      expect(widgets, contains('BackofficeMetricCard'));
      expect(widgets, contains('BackofficeDesktopTable'));
      expect(widgets, contains('hoverColor: BackofficePalette.primarySoft'));
      expect(widgets, contains('BackofficeToolbarPanel'));
    });

    test('le shell est allégé et ne répète plus Espace sécurisé', () {
      final String shell = _read(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      );

      expect(shell, contains('Administrateur · accès complet'));
      expect(shell, contains('Manager · supervision opérationnelle'));
      expect(shell, isNot(contains("'Espace sécurisé'")));
      expect(shell, contains('Color(0xFFF8FAFD)'));
    });

    test('Wave et les opérateurs sont visibles dans les écrans clés', () {
      final String payments = _read(
        'lib/backoffice/presentation/pages/operations/backoffice_payments_page.dart',
      );
      final String finance = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );
      final String dashboard = _read(
        'lib/backoffice/presentation/pages/backoffice_dashboard_page.dart',
      );

      expect(payments, contains('BackofficeWaveBadge'));
      expect(finance, contains('BackofficeFinanceModule.waveCash'));
      expect(finance, contains('BackofficeWaveBadge'));
      expect(dashboard, contains('IzyTelOperatorLogo'));
      expect(dashboard, contains('MobileNetwork.orange'));
      expect(dashboard, contains('MobileNetwork.mtn'));
      expect(dashboard, contains('MobileNetwork.moov'));
    });

    test('les libellés techniques BO ne sont plus exposés dans les zones retouchées', () {
      final String finance = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );
      final String users = _read(
        'lib/backoffice/presentation/pages/backoffice_users_page.dart',
      );

      expect(finance, isNot(contains("eyebrow: 'BO-5")));
      expect(users, isNot(contains('BO-1 expose le registre réel')));
    });
  });
}
