import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_territory_map.dart';
import 'package:cabine_flow/backoffice/data/repositories/fake_territory_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_test;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'territory_map_test.dart' as fixtures;

class CapturedTiles extends TileProvider {
  final requested = <String>{};
  final images = <String, ImageProvider>{};
  int lastZoom = 0;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    lastZoom = coordinates.z;
    final name = '${coordinates.z}/${coordinates.x}/${coordinates.y}';
    requested.add(name);
    final file = File('scratch/territory_map_tiles/$name.png');
    return images.putIfAbsent(
      name,
      () => file.existsSync()
          ? MemoryImage(file.readAsBytesSync())
          : MemoryImage(
              base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
              ),
            ),
    );
  }
}

void main() {
  final enabled = Platform.environment['IZYTEL_TERRITORY_CAPTURE'] == '1';
  ThemeData? theme;
  setUpAll(() async {
    if (!enabled) return;
    final regular = File('scratch/ussd_reprise_visual/Manrope-Regular.ttf');
    final cache = Directory('scratch/territory_map_visual/font_cache')
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
  testWidgets('Render the real territorial map at desktop and mobile widths', (
    tester,
  ) async {
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    final missing = <String>{};
    final managers = await FakeTerritoryRepository().fetchManagers();
    for (final width in [1440.0, 768.0, 390.0]) {
      tester.view.physicalSize = Size(width, 920);
      tester.view.devicePixelRatio = 1;
      final boundaryKey = GlobalKey();
      final tiles = CapturedTiles();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            theme: theme,
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(width < 500 ? 16 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Zones & capacités',
                        style: theme!.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text('Votre territoire, en un coup d’œil.'),
                      const SizedBox(height: 24),
                      BackofficeTerritoryMap(
                        zones: fixtures.zones,
                        managers: {for (final m in managers) m.firebaseUid: m},
                        selectedId: null,
                        onSelected: (_) {},
                        tileProvider: tiles,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future.wait(
          tiles.images.values.map(
            (image) => precacheImage(image, boundaryKey.currentContext!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'docs/territory_map/visual_qa/map-${width.toInt()}.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      final camera = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!
          .camera;
      final bounds = camera.visibleBounds;
      final nw = camera.projectAtZoom(
        LatLng(bounds.north, bounds.west),
        tiles.lastZoom.toDouble(),
      );
      final se = camera.projectAtZoom(
        LatLng(bounds.south, bounds.east),
        tiles.lastZoom.toDouble(),
      );
      missing.addAll(
        tiles.requested.where((p) {
          final c = p.split('/').map(int.parse).toList();
          return c[0] == tiles.lastZoom &&
              c[1] >= (nw.dx / 256).floor() &&
              c[1] <= (se.dx / 256).floor() &&
              c[2] >= (nw.dy / 256).floor() &&
              c[2] <= (se.dy / 256).floor();
        }),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    await tester.runAsync(
      () => File(
        'scratch/territory_map_tiles_requested.json',
      ).writeAsString(jsonEncode(missing.toList())),
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    debugDisableShadows = true;
  }, skip: !enabled);
}
