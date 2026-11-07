import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_test;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cabine_flow/core/theme/app_theme.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/shared_order_queue_repository.dart';
import 'package:cabine_flow/features/orders/presentation/pages/shared_agent_orders_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/order_supervision_page.dart';
import 'shared_order_queue_test.dart' as fixtures;

void main() {
  final capture = Platform.environment['IZYTEL_SHARED_CAPTURE'] == '1';
  ThemeData? theme;
  setUpAll(() async {
    if (!capture) return;
    final regular = File('scratch/ussd_reprise_visual/Manrope-Regular.ttf');
    if (!regular.existsSync()) {
      throw StateError('Local Manrope fixtures are required for visual QA.');
    }
    final cache = Directory('scratch/shared_queue_visual/font_cache')
      ..createSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cache.absolute.path,
        );
    font_test.httpClient = MockClient((request) async {
      final hash = request.url.pathSegments.last.replaceAll('.ttf', '');
      final file =
          hash ==
              '1ddeeeff9fe3d294f709f2239557278930f56dab89db1fe535dc5c35cd67e0ee'
          ? regular
          : File('scratch/ussd_reprise_visual/$hash.ttf');
      return http.Response.bytes(file.readAsBytesSync(), 200);
    });
    theme = AppTheme.light;
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
  final key = GlobalKey();
  Future<void> save(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('docs/shared_queue/visual_qa/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  }

  testWidgets('render the real Agent and Manager widgets for AURA review', (
    tester,
  ) async {
    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      final sample = fixtures.QueueFake();
      await sample.prepare();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Scaffold(
              body: SharedAgentOrdersPage(
                user: fixtures.agent,
                ordersRepository: sample,
                sharedRepository: sample,
              ),
            ),
          ),
        ),
      );
      await save(tester, 'agent-${width.toInt()}');
      if (width == 390) {
        await tester.tap(find.text('Mes commandes'));
        await save(tester, 'agent-personal-390');
      }
      await tester.pumpWidget(const SizedBox());
      await sample.controller.close();
    }
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = fixtures.QueueFake();
    await repo.prepare();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: Scaffold(
            body: SharedAgentOrdersPage(
              user: fixtures.agent,
              ordersRepository: repo,
              sharedRepository: repo,
            ),
          ),
        ),
      ),
    );
    await save(tester, 'agent-390');
    repo.controller.addError(StateError('offline'));
    await save(tester, 'agent-offline-390');
    repo.controller.add(repo.snapshot);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accepter et traiter'));
    await save(tester, 'agent-accepted-390');
    await tester.tap(find.text('Démarrer le traitement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Traitement rapide'));
    await tester.pump(const Duration(seconds: 3));
    await save(tester, 'agent-quick-processing-390');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    repo.snapshot = SharedQueueSnapshot(
      orders: const [],
      serverNow: repo.snapshot.serverNow,
      enabled: true,
    );
    repo.controller.add(repo.snapshot);
    await tester.pump(const Duration(seconds: 4));
    await save(tester, 'agent-empty-390');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await repo.controller.close();
    const manager = AppUser(
      id: 'm1',
      name: 'Manager Test',
      phoneNumber: '0700000002',
      role: UserRole.manager,
    );
    for (final width in [320.0, 390.0, 768.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: OrderSupervisionPage(
              user: manager,
              repository: fixtures.SupervisionFake(),
              historyRepository: FakeOrdersRepository(isTest: true),
            ),
          ),
        ),
      );
      await save(tester, 'manager-${width.toInt()}');
      await tester.tap(find.text('Voir les alertes'));
      await save(tester, 'manager-alerts-${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
    }
  }, skip: !capture);
}
