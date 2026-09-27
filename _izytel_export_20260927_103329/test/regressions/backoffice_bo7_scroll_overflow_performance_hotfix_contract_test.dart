import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('BO-7.1 - overflow et fluidite Web', () {
    test('les grands tableaux utilisent une liste paresseuse bornee', () {
      final String widgets = _read(
        'lib/backoffice/presentation/widgets/backoffice_order_widgets.dart',
      );

      expect(widgets, contains('ListView.builder('));
      expect(widgets, contains('maxBodyHeight = 640'));
      expect(widgets, contains('physics: const ClampingScrollPhysics()'));
      expect(widgets, contains('scrollCacheExtent: const ScrollCacheExtent.pixels(240.0)'));
      expect(widgets, contains('FilterQuality.medium'));
    });

    test('le Web evite le BackdropFilter couteux pendant le scroll modal', () {
      final String modal = _read(
        'lib/backoffice/presentation/widgets/backoffice_modal.dart',
      );

      expect(modal, contains("import 'package:flutter/foundation.dart';"));
      expect(modal, contains('if (kIsWeb) return content;'));
      expect(modal, contains('barrierColor: const Color(0x7A0F172A)'));
      expect(modal, contains('physics: const ClampingScrollPhysics()'));
    });

    test('commandes et paiements donnent assez de largeur aux badges reseau', () {
      final String orders = _read(
        'lib/backoffice/presentation/pages/operations/backoffice_orders_page.dart',
      );
      final String payments = _read(
        'lib/backoffice/presentation/pages/operations/backoffice_payments_page.dart',
      );

      expect(orders, contains("BackofficeTableColumnSpec(label: 'COMMANDE', flex: 3)"));
      expect(orders, contains('compact: true'));
      expect(payments, contains("BackofficeTableColumnSpec(label: 'RÉSEAU', flex: 2)"));
      expect(payments, contains('compact: true'));
    });

    test('le scroll principal du shell utilise une physique Web stable', () {
      final String shell = _read(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      );
      expect(shell, contains('physics: const ClampingScrollPhysics()'));
    });
  });
}
