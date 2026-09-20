import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('la navigation Web synchronise les vues avec l historique navigateur', () {
    final String flow = source(
      'lib/features/customer_order/presentation/pages/customer_order_flow_page.dart',
    );
    final String bridge = source(
      'lib/core/navigation/customer_web_history_web.dart',
    );
    final String viewModel = source(
      'lib/features/customer_order/presentation/view_models/customer_order_view_model.dart',
    );

    expect(flow, contains('CustomerWebHistoryController'));
    expect(flow, contains('_requestBack'));
    expect(flow, contains('_handleBrowserHistoryPop'));
    expect(flow, contains('_restoreHistoryEntry'));
    expect(flow, contains('_CustomerSurface.history'));
    expect(flow, contains('_CustomerSurface.help'));
    expect(flow, contains('_CustomerSurface.catalog'));
    expect(flow, contains('onBack: _requestBack'));
    expect(bridge, contains('window.onPopState'));
    expect(bridge, contains('history.pushState'));
    expect(bridge, contains('history.replaceState'));
    expect(viewModel, contains('restoreNavigationStep'));
  });

  test('les etapes de commande peuvent deleguer leur retour au shell Web', () {
    for (final String path in <String>[
      'lib/features/customer_order/presentation/pages/customer_service_page.dart',
      'lib/features/customer_order/presentation/pages/customer_network_page.dart',
      'lib/features/customer_order/presentation/pages/customer_offer_page.dart',
      'lib/features/customer_order/presentation/pages/customer_beneficiary_page.dart',
      'lib/features/customer_order/presentation/pages/customer_summary_page.dart',
      'lib/features/customer_order/presentation/pages/customer_payment_page.dart',
    ]) {
      final String value = source(path);
      expect(value, contains('onBack'), reason: path);
    }
  });

  test('le vrai logo WhatsApp est utilise sur le Web client', () {
    final File logo = File('assets/images/whatsapp_logo.png');
    final String help = source(
      'lib/features/support/presentation/pages/customer_help_page.dart',
    );
    final String home = source(
      'lib/features/customer_order/presentation/pages/customer_home_page.dart',
    );
    final String supportButton = source(
      'lib/features/customer_order/presentation/widgets/customer_support_button.dart',
    );

    expect(logo.existsSync(), isTrue);
    expect(logo.lengthSync(), greaterThan(1000));
    expect(help, contains('assets/images/whatsapp_logo.png'));
    expect(home, contains('assets/images/whatsapp_logo.png'));
    expect(supportButton, contains('assets/images/whatsapp_logo.png'));
  });

  test('les appels a action principaux du catalogue sont bleus IzyTel', () {
    final String catalog = source(
      'lib/features/customer_order/presentation/pages/customer_catalog_page.dart',
    );
    final String home = source(
      'lib/features/customer_order/presentation/pages/customer_home_page.dart',
    );
    final String buttons = source(
      'lib/shared/widgets/design_system/izy_tel_buttons.dart',
    );

    expect(catalog, contains('backgroundColor: CustomerAppColors.primary'));
    expect(home, contains('backgroundColor: CustomerAppColors.primary'));
    expect(buttons, contains('backgroundColor: CustomerAppColors.primary'));
    expect(buttons, contains('backgroundColor ?? CustomerAppColors.primaryDeep'));
    expect(buttons, contains('backgroundColor: resolvedBackground'));
  });
}
