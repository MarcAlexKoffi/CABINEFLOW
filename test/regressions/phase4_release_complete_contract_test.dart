import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Phase 4 fige IzyTel 1.0.0+1 et le package Android public', () {
    final String pubspec = source('pubspec.yaml');
    final String gradle = source('android/app/build.gradle.kts');
    final String manifest = source('android/app/src/main/AndroidManifest.xml');

    expect(pubspec, contains('version: 1.0.0+1'));
    expect(gradle, contains('applicationId = "com.izytel.app"'));
    expect(gradle, contains('namespace = "com.izytel.app"'));
    expect(manifest, contains('android:label="IzyTel"'));
  });

  test('Phase 4 interdit la signature debug pour release', () {
    final String gradle = source('android/app/build.gradle.kts');
    final String gitignore = source('android/.gitignore');

    expect(gradle, contains('rootProject.file("key.properties")'));
    expect(gradle, contains('create("release")'));
    expect(gradle, contains('signingConfigs.getByName("release")'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(gitignore, contains('key.properties'));
    expect(gitignore, contains('**/*.jks'));
  });

  test('Phase 4 durcit le manifest release et les notifications', () {
    final String manifest = source('android/app/src/main/AndroidManifest.xml');
    final String colors = source('android/app/src/main/res/values/colors.xml');

    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('android:allowBackup="false"'));
    expect(
      manifest,
      contains('com.google.firebase.messaging.default_notification_icon'),
    );
    expect(manifest, contains('@drawable/ic_launcher_monochrome'));
    expect(
      manifest,
      contains('com.google.firebase.messaging.default_notification_color'),
    );
    expect(colors, contains('name="izytel_notification_color"'));
  });

  test('Phase 4 couvre FCM background, cold start et rotation du token', () {
    final String messaging = source(
      'lib/core/notifications/firebase_messaging_bootstrap.dart',
    );
    final String registry = source(
      'lib/core/notifications/izytel_notification_device_registry.dart',
    );

    expect(messaging, contains('@pragma(\'vm:entry-point\')'));
    expect(messaging, contains('FirebaseMessaging.onBackgroundMessage'));
    expect(messaging, contains('messaging.getInitialMessage()'));
    expect(messaging, contains('messaging.onTokenRefresh.listen'));
    expect(registry, contains('izytel_register_notification_device'));
    expect(registry, contains('izytel_deactivate_notification_device'));
  });

  test('Phase 4 conserve la session Firebase au redemarrage', () {
    final String splash = source(
      'lib/features/splash/presentation/pages/splash_page.dart',
    );
    final String auth = source(
      'lib/features/auth/data/repositories/firebase_auth_repository.dart',
    );

    expect(splash, contains('refreshCurrentAccess()'));
    expect(auth, contains('_firebaseAuth.currentUser'));
    expect(auth, isNot(contains('reload();')));
  });

  test('Phase 4 fournit les outils de livraison locale', () {
    for (final String path in <String>[
      'tool/release/setup_release_signing.ps1',
      'tool/release/register_firebase_sha.ps1',
      'tool/release/build_release.ps1',
      'tool/release/fresh_install.ps1',
      'tool/release/watch_release_logs.ps1',
      'tool/release/PHASE4_RELEASE_ACCEPTANCE.md',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: '$path doit exister.');
    }

    final String shaScript = source('tool/release/register_firebase_sha.ps1');
    final String buildScript = source('tool/release/build_release.ps1');
    final String freshInstall = source('tool/release/fresh_install.ps1');
    final String logWatcher = source('tool/release/watch_release_logs.ps1');
    final String acceptance = source('tool/release/PHASE4_RELEASE_ACCEPTANCE.md');

    expect(shaScript, contains(r'$env:JAVA_HOME = $javaRuntime.JavaHome'));
    expect(buildScript, contains(r'$env:JAVA_HOME = $javaRuntime.JavaHome'));
    expect(freshInstall, contains('Resolve-Adb'));
    expect(logWatcher, contains('Resolve-Adb'));
    expect(acceptance, contains('NE PAS utiliser `adb shell am force-stop`'));
  });
}
