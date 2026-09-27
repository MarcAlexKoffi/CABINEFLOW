import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M5 FCM reste isole de Firestore, App Check et Cloud Functions', () {
    final File source = File(
      'lib/core/notifications/firebase_messaging_bootstrap.dart',
    );
    expect(source.existsSync(), isTrue);

    final String text = source.readAsStringSync();
    expect(text, contains('FirebaseMessaging.onBackgroundMessage'));
    expect(text, contains('FirebaseMessaging.onMessage.listen'));
    expect(text, contains('FirebaseMessaging.onMessageOpenedApp.listen'));
    expect(text, contains('messaging.getInitialMessage()'));
    expect(text, contains('messaging.onTokenRefresh.listen'));
    expect(text, contains("'[FCM][token]"));

    expect(text, isNot(contains('cloud_firestore')));
    expect(text, isNot(contains('FirebaseFirestore')));
    expect(text, isNot(contains('firebase_app_check')));
    expect(text, isNot(contains('FirebaseAppCheck')));
    expect(text, isNot(contains('cloud_functions')));
    expect(text, isNot(contains('FirebaseFunctions')));
  });

  test('M5 initialise FCM apres Firebase et avant runApp', () {
    final String main = File('lib/main.dart').readAsStringSync();
    final int firebase = main.indexOf('await FirebaseBootstrap.initialize();');
    final int messaging =
        main.indexOf('await FirebaseMessagingBootstrap.initialize();');
    final int runAppIndex = main.indexOf('runApp(const CabineFlowApp());');

    expect(firebase, greaterThanOrEqualTo(0));
    expect(messaging, greaterThan(firebase));
    expect(runAppIndex, greaterThan(messaging));
  });

  test('pubspec declare uniquement le plugin FCM requis pour ce jalon', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('firebase_messaging: ^16.4.3'));
    expect(pubspec, isNot(contains('firebase_app_check:')));
    expect(pubspec, isNot(contains('cloud_functions:')));
    expect(pubspec, isNot(contains('flutter_local_notifications:')));
  });
}
