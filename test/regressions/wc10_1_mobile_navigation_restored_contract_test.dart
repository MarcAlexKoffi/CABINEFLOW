import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WC10.3 - Retour mobile suit sous-page -> onglet -> Accueil -> double sortie', () {
    final String shell = File(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    ).readAsStringSync();
    final String partner = File(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    ).readAsStringSync();

    // 1. Un seul PopScope de shell traite le geste systeme. Il inspecte la
    // pile du Navigator actif avant toute action de niveau onglet.
    expect(shell, isNot(contains('NavigatorPopHandler<Object?>')));
    expect(shell, contains('currentNavigator.canPop()'));
    expect(shell, contains('await currentNavigator.maybePop()'));
    expect(partner, isNot(contains('NavigatorPopHandler<Object?>')));
    expect(partner, contains('current.canPop()'));
    expect(partner, contains('await current.maybePop()'));

    // 2. Racine d'un onglet secondaire -> Accueil, jamais sortie directe.
    expect(shell, contains("if (_selectedIndex != 0)"));
    expect(shell, contains("setState(() => _selectedIndex = 0)"));
    expect(partner, contains('_selectTab(0);'));

    // 3. Accueil racine -> premier Retour avertit, second Retour sous 2 s sort.
    expect(shell, contains('DateTime? _lastBackPressAt'));
    expect(shell, contains('Duration(seconds: 2)'));
    expect(shell, contains('Appuie encore une fois pour quitter IzyTel.'));
    expect(shell, contains('await SystemNavigator.pop()'));
    expect(partner, contains('DateTime? _lastBackPressAt'));
    expect(partner, contains('Appuie encore une fois pour quitter IzyTel.'));

    // 4. Toute navigation desarme l'intention de sortie precedente.
    expect(shell, contains('_IzyTelTabNavigationObserver(_disarmExit)'));
    expect(shell, contains('void _disarmExit()'));
    expect(partner, contains('_lastBackPressAt = null;'));

    expect(shell, isNot(contains('IzyTelMobileBackScope(')));
    expect(partner, isNot(contains('IzyTelMobileBackScope(')));
  });
}
