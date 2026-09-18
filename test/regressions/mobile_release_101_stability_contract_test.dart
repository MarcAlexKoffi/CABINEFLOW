import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('release 1.0.1+2 auto-repare FCM au resume', () {
    final String pubspec = source('pubspec.yaml');
    final String messaging = source(
      'lib/core/notifications/firebase_messaging_bootstrap.dart',
    );
    final String registry = source(
      'lib/core/notifications/izytel_notification_device_registry.dart',
    );
    final String shell = source(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );

    expect(pubspec, contains('version: 1.0.1+2'));
    expect(messaging, contains('Future<FirebaseMessagingBootstrapResult> ensureReady'));
    expect(messaging, contains('getNotificationSettings()'));
    expect(messaging, contains('_refreshToken(messaging, maxAttempts: 3)'));
    expect(registry, contains('Future<void> refresh({required AppUser user})'));
    expect(registry, contains('BackendFailurePolicy.retryIdempotent<void>'));
    expect(registry, contains('Firebase.apps.isEmpty'));
    expect(registry, contains('_firebaseUidOrNull()'));
    expect(shell, contains("'FCM.device-registry-start'"));
    expect(shell, contains("'FCM.device-registry-refresh'"));
    expect(shell, contains('with WidgetsBindingObserver'));
    expect(shell, contains('AppLifecycleState.resumed'));
    expect(shell, contains('IzyTelNotificationDeviceRegistry.refresh'));
  });

  test('release 1.0.1+2 preserve la session sur coupure transitoire', () {
    final String auth = source(
      'lib/features/auth/data/repositories/firebase_auth_repository.dart',
    );
    final String policy = source(
      'lib/core/resilience/backend_failure_policy.dart',
    );

    expect(auth, contains('BackendFailurePolicy.retryIdempotent'));
    expect(auth, contains('GetOptions(source: Source.cache)'));
    expect(auth, contains('[Auth][profile-cache-fallback]'));
    expect(auth, contains('Ta session reste ouverte'));
    expect(policy, contains("'network-request-failed'"));
    expect(policy, contains("'failed host lookup'"));
    expect(policy, contains('_looksTransientText(error.toString())'));
  });

  test('indisponibilite reseau n est plus presentee comme erreur rouge', () {
    final String viewModel = source(
      'lib/features/auth/presentation/view_models/login_view_model.dart',
    );
    final String page = source(
      'lib/features/auth/presentation/pages/login_page.dart',
    );
    final String shell = source(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );

    expect(viewModel, contains('showsAvailabilityWarning'));
    expect(page, contains('IzyTelColors.warningSoft'));
    expect(page, contains('Symbols.wifi_off_rounded'));
    expect(shell, contains('FirebaseMessagingBootstrap.permissionStatus'));
    expect(shell, contains('IzyTelFeedbackTone.warning'));
  });
}
