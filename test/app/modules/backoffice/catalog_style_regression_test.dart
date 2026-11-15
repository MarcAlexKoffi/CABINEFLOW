import 'dart:io';
import 'package:cabine_flow/app/data/repositories/fake_admin_offer_repository.dart';
import 'package:cabine_flow/app/domain/entities/auth/app_user.dart';
import 'package:cabine_flow/app/domain/entities/offers/admin_offer.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/modules/backoffice/views/catalog/backoffice_offers_page.dart';
import 'package:cabine_flow/app/theme/backoffice_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as font_test;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ThemeData theme;
  setUpAll(() async {
    final cache = Directory('scratch/catalog_style_font_cache')
      ..createSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cache.absolute.path,
        );
    font_test.httpClient = MockClient((request) async {
      final hash = request.url.pathSegments.last.replaceAll('.ttf', '');
      final file = File(
        'test/support/fonts/manrope/${hash == '1ddeeeff9fe3d294f709f2239557278930f56dab89db1fe535dc5c35cd67e0ee' ? 'Manrope-Regular' : hash}.ttf',
      );
      return http.Response.bytes(file.readAsBytesSync(), 200);
    });
    theme = BackofficeTheme.light;
    await GoogleFonts.pendingFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
          'packages/material_symbols_icons/MaterialSymbolsRounded',
        )..addFont(
          rootBundle.load(
            'packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf',
          ),
        ))
        .load();
  });
  for (final width in [390.0, 930.0]) {
    testWidgets('Existing catalogue card style is unchanged at $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 2100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeAdminOfferRepository(
        initialOffers: [
          const AdminOffer(
            id: 'style-baseline',
            network: MobileNetwork.orange,
            service: OfferService.internet,
            operationType: OrderOperationType.internetSubscription,
            title: '10 Go',
            catalogLabel: 'Internet Orange 10 Go - 7 jours',
            sellingPrice: 2500,
            details: [],
            category: 'internet',
            isActive: true,
            displayOrder: 3,
            volume: '10 Go',
            validity: '7 jours',
          ),
        ],
      );
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: BackofficeOffersPage(
                user: const AppUser(
                  id: 'admin',
                  name: 'Admin',
                  phoneNumber: '',
                  role: UserRole.administrator,
                ),
                repository: repo,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('catalog-card-style-baseline'));
      expect(card, findsOneWidget);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        card,
        matchesGoldenFile('goldens/catalog_card_existing_${width.toInt()}.png'),
      );
    });
  }
}
