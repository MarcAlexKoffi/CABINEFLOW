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

  bool get notificationsAllowed =>
      permissionStatus == 'authorized' || permissionStatus == 'provisional';
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
  static bool _initializing = false;
  static bool _backgroundHandlerRegistered = false;
  static bool _permissionRequestedThisProcess = false;
  static String _permissionStatus = 'notDetermined';
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

  static String get permissionStatus => _permissionStatus;

  static bool get notificationsAllowed =>
      _permissionStatus == 'authorized' || _permissionStatus == 'provisional';

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

  /// Initialise FCM au demarrage. Un echec ne bloque jamais IzyTel et peut etre
  /// repare plus tard par [ensureReady], appele notamment apres authentification
  /// et au retour au premier plan.
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
        permissionStatus: _permissionStatus,
        token: _currentToken,
      );
    }

    if (_initializing) {
      // Evite deux installations concurrentes des listeners pendant un resume
      // tres proche du bootstrap initial.
      for (int attempt = 0; attempt < 20 && _initializing; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return FirebaseMessagingBootstrapResult(
        supported: true,
        permissionStatus: _permissionStatus,
        token: _currentToken,
      );
    }

    _initializing = true;
    try {
      if (!_backgroundHandlerRegistered) {
        FirebaseMessaging.onBackgroundMessage(
          izytelFirebaseMessagingBackgroundHandler,
        );
        _backgroundHandlerRegistered = true;
      }

      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      final NotificationSettings settings =
          await messaging.getNotificationSettings();
      _permissionStatus = settings.authorizationStatus.name;

      await _installListeners(messaging);
      _initialized = true;

      // Ne demande pas l'autorisation Android avant que l'utilisateur ne soit
      // connecte. Si elle etait deja accordee, le token peut etre lu tout de
      // suite ; sinon [ensureReady] affichera la demande au bon moment.
      if (notificationsAllowed) {
        await _refreshToken(messaging, maxAttempts: 2);
      }
      await _captureInitialMessage(messaging);

      IzyTelLog.debug('[FCM][permission] $_permissionStatus');
      IzyTelLog.debug(
        _currentToken == null
            ? '[FCM][token] indisponible'
            : '[FCM][token] disponible',
      );

      return FirebaseMessagingBootstrapResult(
        supported: true,
        permissionStatus: _permissionStatus,
        token: _currentToken,
      );
    } catch (error, stackTrace) {
      // FCM ne doit jamais empecher IzyTel de demarrer. Nettoie aussi les
      // listeners partiellement poses afin qu'un retry ne les duplique pas.
      await _cancelRuntimeSubscriptions();
      _initialized = false;
      _permissionStatus = 'error';
      IzyTelLog.backendError(
        'FCM.bootstrap',
        error,
        stackTrace: stackTrace,
      );
      return const FirebaseMessagingBootstrapResult(
        supported: true,
        permissionStatus: 'error',
      );
    } finally {
      _initializing = false;
    }
  }

  /// Auto-reparation FCM apres authentification ou retour au premier plan.
  ///
  /// - si le bootstrap initial a echoue, il est rejoue ;
  /// - les permissions sont relues (utile apres un changement dans Android) ;
  /// - le token est relu et republie au registre s'il a change ou etait absent.
  static Future<FirebaseMessagingBootstrapResult> ensureReady({
    bool refreshToken = true,
  }) async {
    final FirebaseMessagingBootstrapResult initial = await initialize();
    if (!initial.supported || !_initialized) return initial;

    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    try {
      NotificationSettings settings = await messaging.getNotificationSettings();
      _permissionStatus = settings.authorizationStatus.name;

      if (!notificationsAllowed && !_permissionRequestedThisProcess) {
        _permissionRequestedThisProcess = true;
        settings = await messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        _permissionStatus = settings.authorizationStatus.name;
      }

      if (notificationsAllowed &&
          (refreshToken ||
              _currentToken == null ||
              _currentToken!.trim().isEmpty)) {
        await _refreshToken(messaging, maxAttempts: 3);
      }
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'FCM.ensure-ready',
        error,
        stackTrace: stackTrace,
      );
    }

    return FirebaseMessagingBootstrapResult(
      supported: true,
      permissionStatus: _permissionStatus,
      token: _currentToken,
    );
  }

  static Future<void> _installListeners(FirebaseMessaging messaging) async {
    await _cancelRuntimeSubscriptions();

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
        _publishToken(token, source: 'token-refresh');
      },
      onError: (Object error, StackTrace stackTrace) {
        IzyTelLog.backendError(
          'FCM.token-refresh',
          error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  static Future<void> _refreshToken(
    FirebaseMessaging messaging, {
    required int maxAttempts,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final String? token = await messaging.getToken();
        if (token != null && token.trim().isNotEmpty) {
          _publishToken(token, source: 'token-read');
        }
        return;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt + 1 < maxAttempts) {
          await Future<void>.delayed(
            Duration(milliseconds: 300 * (attempt + 1)),
          );
        }
      }
    }

    if (lastError != null) {
      IzyTelLog.backendError(
        'FCM.token-read',
        lastError,
        stackTrace: lastStackTrace,
      );
    }
  }

  static void _publishToken(String token, {required String source}) {
    final String cleaned = token.trim();
    if (cleaned.isEmpty) return;

    final bool changed = _currentToken != cleaned;
    _currentToken = cleaned;
    if (changed || !_tokenController.hasListener) {
      IzyTelLog.debug('[FCM][$source] token mis a jour');
    }
    // Republie aussi un token identique : le registre Supabase est idempotent
    // et cela permet de reactiver un appareil apres une coupure ou un reinstall.
    scheduleMicrotask(() => _tokenController.add(cleaned));
  }

  static Future<void> _captureInitialMessage(
    FirebaseMessaging messaging,
  ) async {
    try {
      final RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage == null) return;
      final IzyTelNotificationPayload payload =
          _payloadFromRemoteMessage(initialMessage);
      IzyTelLog.debug('[FCM][initial] type=${payload.type}');
      // Le payload est conserve jusqu'a l'ouverture de l'espace Agent/Manager,
      // y compris si une reconnexion est necessaire apres le tap.
      _pendingOpenedPayload = payload;
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'FCM.initial-message',
        error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> _cancelRuntimeSubscriptions() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _foregroundSubscription = null;
    _openedSubscription = null;
    _tokenRefreshSubscription = null;
  }

  static Future<void> disposeForTests() async {
    await _cancelRuntimeSubscriptions();
    _pendingOpenedPayload = null;
    _currentToken = null;
    _permissionStatus = 'notDetermined';
    _initialized = false;
    _initializing = false;
    _backgroundHandlerRegistered = false;
    _permissionRequestedThisProcess = false;
  }
}
