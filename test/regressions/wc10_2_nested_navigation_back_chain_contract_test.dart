import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WC10.3 - un seul gestionnaire consomme Retour Android', () {
    final String shell = File(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    ).readAsStringSync();
    final String partner = File(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    ).readAsStringSync();

    // Aucun second PopScope/handler imbrique ne doit traiter le meme geste.
    expect(shell, isNot(contains('NavigatorPopHandler<Object?>')));
    expect(partner, isNot(contains('NavigatorPopHandler<Object?>')));

    // Le shell unique depile d'abord une vraie sous-page, et seulement ensuite
    // applique onglet secondaire -> Accueil -> double Retour pour quitter.
    expect(shell, contains('currentNavigator.canPop()'));
    expect(shell, contains('await currentNavigator.maybePop()'));
    expect(shell, contains("if (_selectedIndex != 0)"));
    expect(shell, contains('setState(() => _selectedIndex = 0)'));
    expect(shell, contains('Duration(seconds: 2)'));
    expect(shell, contains('Appuie encore une fois pour quitter IzyTel.'));
    expect(shell, contains('await SystemNavigator.pop()'));

    expect(partner, contains('current.canPop()'));
    expect(partner, contains('await current.maybePop()'));
    expect(partner, contains('_selectTab(0);'));
    expect(partner, contains('Duration(seconds: 2)'));
  });
}
