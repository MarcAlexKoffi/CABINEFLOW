import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('BO-7.1 iteration 2 - hotfix analyze', () {
    test('le graphique importe le type PointerHoverEvent', () {
      final String charts = _read(
        'lib/backoffice/presentation/widgets/backoffice_charts.dart',
      );
      expect(charts, contains("import 'package:flutter/gestures.dart';"));
      expect(charts, contains('PointerHoverEvent'));
    });

    test('la fiche utilisateur ne garde pas le composant mort _DetailRow', () {
      final String users = _read(
        'lib/backoffice/presentation/pages/backoffice_users_page.dart',
      );
      expect(users, isNot(contains('class _DetailRow extends StatelessWidget')));
      expect(users, isNot(contains('this.last = false')));
    });
  });
}
