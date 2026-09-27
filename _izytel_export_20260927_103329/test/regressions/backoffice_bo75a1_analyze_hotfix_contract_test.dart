import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BO-7.5A1 analyze hotfix removes the two analyzer findings', () {
    final refunds = File(
      'lib/backoffice/presentation/pages/clients/backoffice_refunds_page.dart',
    ).readAsStringSync();
    final control = File(
      'lib/backoffice/presentation/pages/control/backoffice_control_page.dart',
    ).readAsStringSync();

    expect(refunds, isNot(contains('separatorBuilder: (_, __)')));
    expect(refunds, contains('separatorBuilder: (_, _)'));
    expect(control, isNot(contains('onOpenModule!(event)')));
    expect(control, contains('onOpenModule(event)'));
  });
}
