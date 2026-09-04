import 'dart:async';

import 'package:cabine_flow/core/notifications/izytel_notification_payload.dart';
import 'package:cabine_flow/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> izytelFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  final IzyTelNotificationPayload payload =
      IzyTelNotificationPayload.fromMap(message.data);
  debugPrint(
    '[FCM][background] id=${message.messageId ?? '-'} '
    'type=${payload.type} order=${payload.orderReference ?? payload.orderId ?? '-'}',
  );
}

class FirebaseMessagingBootstrapResult {
  const FirebaseMessagingBootstrapResult({
    required this.supported,
    required this.permissionStatus,
    this.token,
  });

  final bool supported;
  final String permissionStatus;
  final String? token;
}

/// Socle FCM de la Phase 1 Mobile Readiness.
///
/// Cette classe est volontairement isolee du backend metier :
/// - aucune ecriture Firestore ;
/// - aucun App Check ;
/// - aucune Cloud Function ;
/// - aucun stockage Supabase du token pour cette premiere validation.
///
/// L'objectif est d'abord de confirmer que ce build Android peut recevoir FCM
/// sans introduire de dependance critique dans le demarrage d'IzyTel.
class FirebaseMessagingBootstrap {
  FirebaseMessagingBootstrap._();

  static bool _initialized = false;
  static String? _currentToken;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static StreamSubscription<String>? _tokenRefreshSubscription;

  static final StreamController<IzyTelNotificationPayload>
      _foregroundPayloadController =
      StreamController<IzyTelNotificationPayload>.broadcast();

  static final StreamController<IzyTelNotificationPayload>
      _openedPayloadController =
      StreamController<IzyTelNotificationPayload>.broadcast();

  static String? get currentToken => _currentToken;

  static Stream<IzyTelNotificationPayload> get foregroundPayloads =>
      _foregroundPayloadController.stream;

  static Stream<IzyTelNotificationPayload> get openedPayloads =>
      _openedPayloadController.stream;

  static bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<FirebaseMessagingBootstrapResult> initialize() async {
    if (!_isSupportedPlatform) {
      debugPrint('[FCM] plateforme ignoree pour le mobile IzyTel.');
      return const FirebaseMessagingBootstrapResult(
        supported: false,
        permissionStatus: 'unsupported',
      );
    }

    if (_initialized) {
      return FirebaseMessagingBootstrapResult(
        supported: true,
        permissionStatus: 'already_initialized',
        token: _currentToken,
      );
    }

    _initialized = true;

    try {
      FirebaseMessaging.onBackgroundMessage(
        izytelFirebaseMessagingBackgroundHandler,
      );

      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      final NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      _currentToken = await messaging.getToken();
      debugPrint(
        '[FCM][permission] ${settings.authorizationStatus.name}',
      );
      debugPrint(
        _currentToken == null
            ? '[FCM][token] indisponible'
            : '[FCM][token] $_currentToken',
      );

      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) {
          final IzyTelNotificationPayload payload =
              IzyTelNotificationPayload.fromMap(message.data);
          debugPrint(
            '[FCM][foreground] id=${message.messageId ?? '-'} '
            'type=${payload.type} '
            'order=${payload.orderReference ?? payload.orderId ?? '-'}',
          );
          _foregroundPayloadController.add(payload);
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('[FCM][foreground-error] $error');
          debugPrintStack(stackTrace: stackTrace);
        },
      );

      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
          final IzyTelNotificationPayload payload =
              IzyTelNotificationPayload.fromMap(message.data);
          debugPrint(
            '[FCM][opened] id=${message.messageId ?? '-'} '
            'type=${payload.type} '
            'order=${payload.orderReference ?? payload.orderId ?? '-'}',
          );
          _openedPayloadController.add(payload);
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('[FCM][opened-error] $error');
          debugPrintStack(stackTrace: stackTrace);
        },
      );

      _tokenRefreshSubscription = messaging.onTokenRefresh.listen(
        (String token) {
          _currentToken = token;
          debugPrint('[FCM][token-refresh] $token');
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('[FCM][token-refresh-error] $error');
          debugPrintStack(stackTrace: stackTrace);
        },
      );

      final RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        final IzyTelNotificationPayload payload =
            IzyTelNotificationPayload.fromMap(initialMessage.data);
        debugPrint(
          '[FCM][initial] id=${initialMessage.messageId ?? '-'} '
          'type=${payload.type} '
          'order=${payload.orderReference ?? payload.orderId ?? '-'}',
        );
        // Le routage vers les ecrans metier sera branche apres validation FCM.
        scheduleMicrotask(() => _openedPayloadController.add(payload));
      }

      return FirebaseMessagingBootstrapResult(
        supported: true,
        permissionStatus: settings.authorizationStatus.name,
        token: _currentToken,
      );
    } catch (error, stackTrace) {
      // FCM ne doit jamais empecher IzyTel de demarrer.
      _initialized = false;
      debugPrint('[FCM][bootstrap-error] $error');
      debugPrintStack(stackTrace: stackTrace);
      return const FirebaseMessagingBootstrapResult(
        supported: true,
        permissionStatus: 'error',
      );
    }
  }

  static Future<void> disposeForTests() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _foregroundSubscription = null;
    _openedSubscription = null;
    _tokenRefreshSubscription = null;
    _currentToken = null;
    _initialized = false;
  }
}
