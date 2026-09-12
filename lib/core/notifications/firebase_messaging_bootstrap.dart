import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
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

  final IzyTelNotificationPayload payload = _payloadFromRemoteMessage(message);
  IzyTelLog.debug('[FCM][background] type=${payload.type}');
}

IzyTelNotificationPayload _payloadFromRemoteMessage(RemoteMessage message) {
  final Map<String, dynamic> data = <String, dynamic>{...message.data};
  final String? title = message.notification?.title?.trim();
  final String? body = message.notification?.body?.trim();
  if (title != null && title.isNotEmpty) data.putIfAbsent('title', () => title);
  if (body != null && body.isNotEmpty) data.putIfAbsent('body', () => body);
  return IzyTelNotificationPayload.fromMap(data);
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

/// Socle FCM Mobile Readiness IzyTel.
///
/// Firebase reste uniquement le transport de notifications :
/// - aucune ecriture Firestore ;
/// - aucun App Check ;
/// - aucune Cloud Function Firebase ;
/// - aucun secret serveur embarque dans le mobile.
class FirebaseMessagingBootstrap {
  FirebaseMessagingBootstrap._();

  static bool _initialized = false;
  static String? _currentToken;
  static IzyTelNotificationPayload? _pendingOpenedPayload;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static StreamSubscription<String>? _tokenRefreshSubscription;

  static final StreamController<IzyTelNotificationPayload>
      _foregroundPayloadController =
      StreamController<IzyTelNotificationPayload>.broadcast();

  static final StreamController<IzyTelNotificationPayload>
      _openedPayloadController =
      StreamController<IzyTelNotificationPayload>.broadcast();

  static final StreamController<String> _tokenController =
      StreamController<String>.broadcast();

  static String? get currentToken => _currentToken;

  static Stream<String> get tokenChanges => _tokenController.stream;

  static Stream<IzyTelNotificationPayload> get foregroundPayloads =>
      _foregroundPayloadController.stream;

  static Stream<IzyTelNotificationPayload> get openedPayloads =>
      _openedPayloadController.stream;

  static IzyTelNotificationPayload? takePendingOpenedPayload() {
    final IzyTelNotificationPayload? payload = _pendingOpenedPayload;
    _pendingOpenedPayload = null;
    return payload;
  }

  static bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<FirebaseMessagingBootstrapResult> initialize() async {
    if (!_isSupportedPlatform) {
      IzyTelLog.debug('[FCM] plateforme ignoree pour le mobile IzyTel.');
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
      IzyTelLog.debug(
        '[FCM][permission] ${settings.authorizationStatus.name}',
      );
      IzyTelLog.debug(
        _currentToken == null
            ? '[FCM][token] indisponible'
            : '[FCM][token] disponible',
      );
      final String? initialToken = _currentToken;
      if (initialToken != null && initialToken.trim().isNotEmpty) {
        scheduleMicrotask(() => _tokenController.add(initialToken));
      }

      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) {
          final IzyTelNotificationPayload payload =
              _payloadFromRemoteMessage(message);
          IzyTelLog.debug('[FCM][foreground] type=${payload.type}');
          _foregroundPayloadController.add(payload);
        },
        onError: (Object error, StackTrace stackTrace) {
          IzyTelLog.backendError(
            'FCM.foreground',
            error,
            stackTrace: stackTrace,
          );
        },
      );

      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
          final IzyTelNotificationPayload payload =
              _payloadFromRemoteMessage(message);
          IzyTelLog.debug('[FCM][opened] type=${payload.type}');
          if (_openedPayloadController.hasListener) {
            _openedPayloadController.add(payload);
          } else {
            _pendingOpenedPayload = payload;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          IzyTelLog.backendError(
            'FCM.opened',
            error,
            stackTrace: stackTrace,
          );
        },
      );

      _tokenRefreshSubscription = messaging.onTokenRefresh.listen(
        (String token) {
          _currentToken = token;
          IzyTelLog.debug('[FCM][token-refresh] token mis a jour');
          _tokenController.add(token);
        },
        onError: (Object error, StackTrace stackTrace) {
          IzyTelLog.backendError(
            'FCM.token-refresh',
            error,
            stackTrace: stackTrace,
          );
        },
      );

      final RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        final IzyTelNotificationPayload payload =
            _payloadFromRemoteMessage(initialMessage);
        IzyTelLog.debug('[FCM][initial] type=${payload.type}');
        // Le payload est conserve jusqu'a l'ouverture de l'espace Agent/Manager,
        // y compris si une reconnexion est necessaire apres le tap.
        _pendingOpenedPayload = payload;
      }

      return FirebaseMessagingBootstrapResult(
        supported: true,
        permissionStatus: settings.authorizationStatus.name,
        token: _currentToken,
      );
    } catch (error, stackTrace) {
      // FCM ne doit jamais empecher IzyTel de demarrer.
      _initialized = false;
      IzyTelLog.backendError(
        'FCM.bootstrap',
        error,
        stackTrace: stackTrace,
      );
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
    _pendingOpenedPayload = null;
    _currentToken = null;
    _initialized = false;
  }
}
