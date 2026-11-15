import 'dart:io';
import 'package:cabine_flow/app/theme/backoffice_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as font_test;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<ThemeData> catalogVisualTheme() async {
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
  final theme = BackofficeTheme.light;
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
  return theme;
}
