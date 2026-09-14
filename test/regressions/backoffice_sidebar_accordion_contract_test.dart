import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Back-office - navigation par catégories', () {
    test('la sidebar utilise des catégories repliables premium', () {
      final String shell = File(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      ).readAsStringSync();
      expect(shell, contains('class _BackofficeSidebar extends StatefulWidget'));
      expect(shell, contains('class _BackofficeSectionMenu'));
      expect(shell, contains('AnimatedSize('));
      expect(shell, contains('AnimatedRotation('));
      expect(shell, contains('_expandedSection'));
      expect(shell, contains('section.menuLabel'));
      expect(shell, contains('keyboard_arrow_down_rounded'));
      expect(shell, contains('compact: true'));
      expect(shell, contains('border: Border('));
      expect(shell, contains('left: BorderSide('));
      expect(shell, contains('fontSize: compact ? 12.5 : null'));
      expect(shell, contains('width: compact ? 3 : 6'));
    });

    test('le tableau de bord reste direct et les autres modules sont regroupés', () {
      final String shell = File(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      ).readAsStringSync();
      expect(shell, contains('BackofficeDestination.dashboard'));
      expect(shell, contains("return 'Opérations';"));
      expect(shell, contains("return 'Clients';"));
      expect(shell, contains("return 'Équipe';"));
      expect(shell, contains("return 'Administration';"));
      expect(shell, contains("return 'Finances';"));
      expect(shell, contains("return 'Contrôle';"));
      expect(shell, contains("return 'Pilotage';"));
    });

    test('la catégorie de la destination active est réouverte automatiquement', () {
      final String shell = File(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      ).readAsStringSync();
      expect(shell, contains('didUpdateWidget'));
      expect(shell, contains('widget.selected.section'));
      expect(shell, contains('_expandedSection = section'));
    });
  });
}
