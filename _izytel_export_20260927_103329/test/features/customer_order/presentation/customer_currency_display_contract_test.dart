import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les montants client n’ajoutent pas une seconde devise', () {
    final List<String> files = <String>[
      'lib/features/customer_order/presentation/pages/customer_payment_page.dart',
      'lib/features/customer_order/presentation/pages/customer_order_history_page.dart',
      'lib/features/customer_order/presentation/pages/customer_home_page.dart',
      'lib/features/customer_order/presentation/pages/customer_summary_page.dart',
      'lib/features/customer_order/presentation/pages/customer_catalog_page.dart',
    ];

    for (final String path in files) {
      final String source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('} F CFA')),
        reason: 'Double devise détectée dans $path',
      );
    }
  });

  test('les champs de montant réservent une zone fixe à F CFA', () {
    final String input = File(
      'lib/shared/widgets/design_system/izy_tel_inputs.dart',
    ).readAsStringSync();
    final String customerOffer = File(
      'lib/features/customer_order/presentation/pages/customer_offer_page.dart',
    ).readAsStringSync();
    final String createOrder = File(
      'lib/features/orders/presentation/pages/create_order_page.dart',
    ).readAsStringSync();

    expect(input, contains('suffixIconConstraints'));
    expect(input, contains('minWidth: 72'));
    expect(customerOffer, contains("suffixText: 'F CFA'"));
    expect(createOrder, contains("suffixText: 'F CFA'"));
    expect(createOrder, contains('suffixIconConstraints'));
  });
}
