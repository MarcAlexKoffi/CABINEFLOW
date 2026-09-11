import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('la version Web conserve le parcours client et la session locale', () {
    final String entry = source('lib/main_customer_web.dart');
    final String flow = source(
      'lib/features/customer_order/presentation/pages/customer_order_flow_page.dart',
    );

    expect(entry, contains('Persistence.LOCAL'));
    expect(flow, contains('CustomerIdentificationPage'));
    expect(flow, contains('CustomerServicePage'));
    expect(flow, contains('CustomerNetworkPage'));
    expect(flow, contains('CustomerOfferPage'));
    expect(flow, contains('CustomerBeneficiaryPage'));
    expect(flow, contains('CustomerSummaryPage'));
    expect(flow, contains('CustomerPaymentPage'));
    expect(flow, contains('CustomerConfirmationPage'));
  });

  test('la page d accueil Web utilise le nouveau langage visuel IzyTel', () {
    final String home = source(
      'lib/features/customer_order/presentation/pages/customer_home_page.dart',
    );

    expect(home, contains('IZYTEL WEB'));
    expect(home, contains(r'Rechargez.\nContinuez.'));
    expect(home, contains('class _PhonePreview'));
    expect(home, contains('Simple. Rapide. Izy.'));
    expect(home, contains('assets/images/izyTel_logo.png'));
    expect(home, isNot(contains('assets/images/splash_illustration.png')));
  });

  test('le theme client Web utilise Manrope et le design system premium', () {
    final String theme = source('lib/core/theme/customer_app_theme.dart');
    final String shell = source(
      'lib/shared/widgets/design_system/izy_tel_shell.dart',
    );
    final String cards = source(
      'lib/shared/widgets/design_system/izy_tel_cards.dart',
    );

    expect(theme, contains('GoogleFonts.manropeTextTheme'));
    expect(theme, contains('borderRadius: BorderRadius.circular(16)'));
    expect(shell, contains('assets/images/izyTel_logo.png'));
    expect(shell, contains('_AmbientCircle'));
    expect(cards, contains('MouseRegion'));
    expect(cards, contains('AnimatedScale'));
  });

  test('le shell Web natif expose le branding, le loader et la PWA IzyTel', () {
    final String html = source('web/index.html');
    final String manifest = source('web/manifest.json');

    expect(html, contains('<html lang="fr">'));
    expect(html, contains('IzyTel Web — Recharge en ligne'));
    expect(html, contains('id="izytel-loader"'));
    expect(html, contains('flutter-first-frame'));
    expect(html, contains('branding/izytel-mark.png'));
    expect(html, contains('apple-touch-icon.png'));

    expect(manifest, contains('"name": "IzyTel Web"'));
    expect(manifest, contains('"orientation": "any"'));
    expect(manifest, contains('"theme_color": "#0757C9"'));

    for (final String path in <String>[
      'web/favicon.png',
      'web/apple-touch-icon.png',
      'web/branding/izytel-mark.png',
      'web/icons/Icon-192.png',
      'web/icons/Icon-512.png',
      'web/icons/Icon-maskable-192.png',
      'web/icons/Icon-maskable-512.png',
    ]) {
      final File file = File(path);
      expect(file.existsSync(), isTrue, reason: path);
      expect(file.lengthSync(), greaterThan(1000), reason: path);
    }
  });
}
