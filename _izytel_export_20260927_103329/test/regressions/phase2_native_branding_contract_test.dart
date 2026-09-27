import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('branding Android natif IzyTel avec package release definitif', () {
    final String manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final String gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final String splash = File(
      'android/app/src/main/res/drawable/launch_background.xml',
    ).readAsStringSync();
    final String android12 = File(
      'android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();
    final String adaptive = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    final String themed = File(
      'android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:label="IzyTel"'));
    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));

    // Phase 4B fige désormais l'identité Android publique d'IzyTel.
    expect(gradle, contains('applicationId = "com.izytel.app"'));
    expect(gradle, contains('namespace = "com.izytel.app"'));

    expect(splash, contains('@drawable/izytel_splash_logo'));
    expect(android12, contains('android:windowSplashScreenAnimatedIcon'));
    expect(android12, contains('@mipmap/ic_launcher'));
    expect(adaptive, contains('@drawable/ic_launcher_foreground'));
    expect(themed, contains('@drawable/ic_launcher_monochrome'));

    for (final String density in <String>[
      'mdpi',
      'hdpi',
      'xhdpi',
      'xxhdpi',
      'xxxhdpi',
    ]) {
      expect(
        File('android/app/src/main/res/mipmap-$density/ic_launcher.png').existsSync(),
        isTrue,
      );
      expect(
        File(
          'android/app/src/main/res/mipmap-$density/ic_launcher_round.png',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          'android/app/src/main/res/drawable-$density/izytel_splash_logo.png',
        ).existsSync(),
        isTrue,
      );
    }
  });
}
