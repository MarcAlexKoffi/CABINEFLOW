import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const packageName = 'com.izytel.app';
  const newFirebaseAppId = '1:542869507309:android:6719f71b043fae652f10e4';
  const oldPackageName = 'com.cabineflow.cabine_flow';
  const oldFirebaseAppId = '1:542869507309:android:127acb5d3519466f2f10e4';

  test('Phase 4B utilise l identite Android IzyTel definitive', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('namespace = "$packageName"'));
    expect(gradle, contains('applicationId = "$packageName"'));
    expect(gradle, isNot(contains(oldPackageName)));

    final newMainActivity =
        File('android/app/src/main/kotlin/com/izytel/app/MainActivity.kt');
    expect(newMainActivity.existsSync(), isTrue);
    expect(newMainActivity.readAsStringSync(), contains('package $packageName'));

    final oldMainActivity = File(
      'android/app/src/main/kotlin/com/cabineflow/cabine_flow/MainActivity.kt',
    );
    expect(
      oldMainActivity.existsSync(),
      isFalse,
      reason: 'L ancien MainActivity CabineFlow doit etre supprime apres le cutover.',
    );
  });

  test('Phase 4B utilise la nouvelle application Firebase Android IzyTel', () {
    final googleServicesFile = File('android/app/google-services.json');
    expect(googleServicesFile.existsSync(), isTrue);

    final googleServices = jsonDecode(googleServicesFile.readAsStringSync())
        as Map<String, dynamic>;
    final clients = (googleServices['client'] as List<dynamic>? ?? const []);

    final matchingClient = clients.cast<Map<String, dynamic>>().where((client) {
      final clientInfo = client['client_info'] as Map<String, dynamic>?;
      final androidInfo =
          clientInfo?['android_client_info'] as Map<String, dynamic>?;
      return androidInfo?['package_name'] == packageName;
    }).toList();

    expect(matchingClient, hasLength(1));
    final clientInfo =
        matchingClient.single['client_info'] as Map<String, dynamic>;
    expect(clientInfo['mobilesdk_app_id'], newFirebaseAppId);

    final firebaseOptions = File('lib/firebase_options.dart').readAsStringSync();
    expect(firebaseOptions, contains(newFirebaseAppId));
    expect(firebaseOptions, isNot(contains(oldFirebaseAppId)));

    final firebaseJson = File('firebase.json').readAsStringSync();
    expect(firebaseJson, contains(newFirebaseAppId));
    expect(firebaseJson, isNot(contains(oldFirebaseAppId)));
  });
}
