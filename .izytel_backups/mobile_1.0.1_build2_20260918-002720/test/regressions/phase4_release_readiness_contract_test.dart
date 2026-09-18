import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 4 release garde le branding et le versioning IzyTel v1', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final String manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(pubspec, contains('version: 1.0.0+1'));
    expect(manifest, contains('android:label="IzyTel"'));
  });

  test('Phase 4 release a les permissions reseau et notification', () {
    final String manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android.permission.INTERNET'),
      reason: 'Le manifest main doit couvrir le build release.',
    );
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
  });

  test('Phase 4 release ne signe plus avec la cle debug', () {
    final String gradle = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();

    expect(gradle, contains('rootProject.file("key.properties")'));
    expect(gradle, contains('create("release")'));
    expect(gradle, contains('signingConfigs.getByName("release")'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
  });

  test('Phase 4 FCM couvre background, cold start et token refresh', () {
    final String messaging = File(
      'lib/core/notifications/firebase_messaging_bootstrap.dart',
    ).readAsStringSync();
    final String registry = File(
      'lib/core/notifications/izytel_notification_device_registry.dart',
    ).readAsStringSync();

    expect(messaging, contains('FirebaseMessaging.onBackgroundMessage'));
    expect(messaging, contains('messaging.getInitialMessage()'));
    expect(messaging, contains('messaging.onTokenRefresh.listen'));
    expect(registry, contains('izytel_register_notification_device'));
  });
}
