import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('le branding visible reste IzyTel sans renommer le package technique', () {
    final String app = source('lib/app/app.dart');
    final String pubspec = source('pubspec.yaml');
    final String shell = source(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );
    final String more = source(
      'lib/features/more/presentation/pages/more_page.dart',
    );

    expect(app, contains("title: 'IzyTel'"));
    expect(pubspec, contains('name: cabine_flow'));
    expect(
      shell,
      contains('Tu devras te reconnecter pour accéder de nouveau à IzyTel.'),
    );
    expect(
      shell,
      isNot(contains('accéder de nouveau à la cabine')),
    );
    expect(more, contains('Supervision opérationnelle et suivi IzyTel.'));
  });

  test('la marque et le splash partagent la même signature IzyTel', () {
    final String brand = source(
      'lib/shared/widgets/izytel/izytel_brand.dart',
    );
    final String splash = source(
      'lib/features/splash/presentation/pages/splash_page.dart',
    );

    expect(brand, contains("'Simple. Rapide. Izy.'"));
    expect(splash, contains("'Simple. Rapide. Izy.'"));
    expect(splash, contains("'assets/images/New_splash_illustration.png'"));
    expect(splash, contains('IzyTelBrandMark'));
    expect(splash, contains("semanticLabel: 'Illustration IzyTel'"));
  });

  test('les écrans opérationnels historiques utilisent la palette claire IzyTel', () {
    const List<String> paths = <String>[
      'lib/features/orders/presentation/pages/create_order_page.dart',
      'lib/features/orders/presentation/pages/customer_confirmation_page.dart',
      'lib/features/orders/presentation/pages/order_processing_page.dart',
      'lib/features/orders/presentation/widgets/order_display_helpers.dart',
      'lib/features/payments/presentation/pages/send_wave_link_page.dart',
    ];

    for (final String path in paths) {
      final String value = source(path);
      expect(value, contains('izytel_colors.dart'), reason: path);
      expect(value, isNot(contains('core/theme/app_colors.dart')), reason: path);
      expect(value, isNot(contains('AppColors.')), reason: path);
    }
  });

  test('le thème global applique les finitions premium sans changer la logique', () {
    final String theme = source('lib/core/theme/app_theme.dart');

    expect(theme, contains('GoogleFonts.manrope'));
    expect(theme, contains('TextSelectionThemeData'));
    expect(theme, contains('CheckboxThemeData'));
    expect(theme, contains('ChipThemeData'));
    expect(theme, contains('_IzyTelPageTransitionsBuilder'));
    expect(theme, contains('IzyTelColors.primarySoft'));
  });

  test('l accès Administrateur mobile reste présent pendant la Phase 2', () {
    final String shell = source(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );
    final String navigation = source(
      'lib/features/dashboard/presentation/widgets/dashboard_widgets.dart',
    );

    expect(shell, contains('FinancesPage('));
    expect(shell, contains('widget.user.isManager'));
    expect(navigation, contains("label: 'Finances'"), reason: 'navigation Admin');
  });
}
