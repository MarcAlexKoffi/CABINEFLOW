import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WC10.3 - un geste Retour Android ne peut etre traite qu une fois', () {
    final String shell = File(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    ).readAsStringSync();
    final String partner = File(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    ).readAsStringSync();

    expect(shell, isNot(contains('NavigatorPopHandler<Object?>')));
    expect(
      RegExp(r'currentNavigator != null && currentNavigator\.canPop\(\)')
          .allMatches(shell)
          .length,
      greaterThanOrEqualTo(2),
    );
    expect(
      RegExp(r'await currentNavigator\.maybePop\(\)').allMatches(shell).length,
      greaterThanOrEqualTo(2),
    );
    expect(shell, contains('if (_selectedIndex != 0)'));
    expect(shell, contains('Duration(seconds: 2)'));
    expect(shell, contains('await SystemNavigator.pop()'));

    expect(partner, isNot(contains('NavigatorPopHandler<Object?>')));
    expect(partner, contains('current != null && current.canPop()'));
    expect(partner, contains('await current.maybePop()'));
    expect(partner, contains('_selectTab(0);'));
    expect(partner, contains('Duration(seconds: 2)'));
  });
}
