import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les montants client n’ajoutent pas une seconde devise', () {
    final List<String> files = <String>[
      'lib/app/modules/customer/views/customer_payment_page.dart',
      'lib/app/modules/customer/views/customer_order_history_page.dart',
      'lib/app/modules/customer/views/customer_home_page.dart',
      'lib/app/modules/customer/views/customer_summary_page.dart',
      'lib/app/modules/customer/views/customer_catalog_page.dart',
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
      'lib/app/shared/widgets/design_system/izy_tel_inputs.dart',
    ).readAsStringSync();
    final String customerOffer = File(
      'lib/app/modules/customer/views/customer_offer_page.dart',
    ).readAsStringSync();
    final String createOrder = File(
      'lib/app/modules/staff_orders/views/create_order_page.dart',
    ).readAsStringSync();

    expect(input, contains('suffixIconConstraints'));
    expect(input, contains('minWidth: 72'));
    expect(customerOffer, contains("suffixText: 'F CFA'"));
    expect(createOrder, contains("suffixText: 'F CFA'"));
    expect(createOrder, contains('suffixIconConstraints'));
  });
}
