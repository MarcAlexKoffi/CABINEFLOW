import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

String _singleLine(String source) => source.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  group('Web client - responsive, startup et Realtime', () {
    test('le signal catalogue est partage et accepte plusieurs ecoutes', () {
      final String customer = _read(
        'lib/features/customer_order/data/repositories/supabase_customer_offer_repository.dart',
      );
      final String staff = _read(
        'lib/features/orders/data/repositories/supabase_offer_catalog_repository.dart',
      );

      for (final String source in <String>[customer, staff]) {
        expect(source, contains('_changeFeedStream'));
        expect(source, contains('.asBroadcastStream()'));
        expect(source, contains('await for'));
      }
      expect(
        customer,
        contains('Bad state: Stream has already been listened to'),
      );
    });

    test('le bootstrap Web ne serialise plus les latences inutiles', () {
      final String customerMain = _read('lib/main_customer_web.dart');
      final String backofficeMain = _read('lib/main_backoffice_web.dart');
      final String supabase = _read('lib/core/supabase/supabase_bootstrap.dart');

      expect(customerMain, isNot(contains('await auth.authStateChanges().first')));
      expect(backofficeMain, contains('final Future<User?> restoredSession'));
      expect(backofficeMain, contains('final Future<bool> supabaseReady'));
      expect(supabase, contains('unawaited(_syncRealtimeAuth'));
      expect(supabase, isNot(contains('await _syncRealtimeAuth(FirebaseAuth.instance.currentUser)')));
    });

    test('le Web desktop n utilise plus la navigation mobile en bas', () {
      final String catalog = _read(
        'lib/features/customer_order/presentation/pages/customer_catalog_page.dart',
      );
      final String history = _read(
        'lib/features/customer_order/presentation/pages/customer_order_history_page.dart',
      );
      final String help = _read(
        'lib/features/support/presentation/pages/customer_help_page.dart',
      );
      final String home = _read(
        'lib/features/customer_order/presentation/pages/customer_home_page.dart',
      );
      final String buttons = _read(
        'lib/shared/widgets/design_system/izy_tel_buttons.dart',
      );

      expect(catalog, contains('bottomNavigationBar: desktopHeader'));
      expect(catalog, contains('? null'));
      expect(catalog, contains("child: const Text('Historique')"));
      expect(
        _singleLine(history),
        contains('bottomNavigationBar: desktop ? null'),
      );
      expect(
        _singleLine(help),
        contains('bottomNavigationBar: desktopHeader ? null'),
      );
      expect(home, contains('constraints.maxWidth >= 980'));
      expect(home, contains("text: 'Commander maintenant'"));
      expect(buttons, contains('Flexible('));
      expect(buttons, contains('overflow: TextOverflow.ellipsis'));
    });
  });
}
