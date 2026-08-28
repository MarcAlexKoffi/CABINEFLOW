import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le Web client ne réintroduit pas SelectionArea global', () {
    final File source = File('lib/customer_order_app.dart');
    final String text = source.readAsStringSync();

    expect(text.contains('SelectionArea('), isFalse);
    expect(text.contains('builder:'), isFalse);
  });
}
